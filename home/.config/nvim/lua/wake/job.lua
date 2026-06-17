-- Spawn the headless wake-stream patcher on save and ingest its repo-wide queue.
local state = require("wake.state")
local paths = require("wake.paths")
local patch = require("wake.patch")
local render = require("wake.render")
local store = require("wake.store")
local panel = require("wake.panel")
local log = require("wake.log")

local M = {}
local cfg
local spinner_timer

function M.init(config) cfg = config end

local function write_file(path, text)
	local f = io.open(path, "w")
	if not f then return false end
	f:write(text); f:close()
	return true
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local data = f:read("*a"); f:close()
	return data
end

local function start_spinner()
	if spinner_timer then return end
	spinner_timer = vim.uv.new_timer()
	spinner_timer:start(0, cfg.spinner_ms, vim.schedule_wrap(function()
		if store.active <= 0 then return end
		render.tick()
	end))
end

local function stop_spinner()
	if store.active <= 0 and spinner_timer then
		spinner_timer:stop()
		if not spinner_timer:is_closing() then spinner_timer:close() end
		spinner_timer = nil
	end
end

local function refresh()
	render.refresh_visible()
	panel.render()
	render.indicator()
end

local function ingest(info, default_rel, runid)
	local qpath = info.inbox .. "/" .. runid .. ".json"
	local raw = read_file(qpath)
	os.remove(qpath)
	os.remove(info.stream .. "/prev-" .. runid .. ".txt")
	if not raw then
		store.last_error = ("patcher exited 0 but wrote no queue file:\n  %s\n\n--- stdout ---\n%s")
			:format(qpath, store.last_stdout or "(empty)")
		return false
	end
	log.debug("queue raw", raw)
	local ok, decoded = pcall(vim.json.decode, raw)
	if not ok or type(decoded) ~= "table" then
		store.last_error = "queue file is not valid JSON:\n\n" .. raw
		return false
	end
	local entries = {}
	for _, rp in ipairs(decoded.patches or {}) do
		local np = patch.normalize(rp)
		if #np.old_lines > 0 then
			np.file_rel = rp.file or default_rel
			np.file_abs = vim.fs.normalize(info.root .. "/" .. np.file_rel)
			np.key = np.file_abs .. "\0" .. np.key
			entries[#entries + 1] = np
		end
	end
	local added = store.add(entries)
	log.info("ingest", { bytes = #raw, queued = #(decoded.patches or {}), parsed = #entries, added = added })
	return true
end

function M.run(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then return end
	local info = paths.resolve(file)
	if not info then return end

	local s = state.get(buf)
	if s.job then pcall(function() s.job:kill(9) end) end

	vim.fn.mkdir(info.inbox, "p")
	s.runid = ("%d-%d"):format(buf, vim.uv.hrtime())
	local runid = s.runid
	local prevfile = info.stream .. "/prev-" .. runid .. ".txt"
	local had_prev = s.prev ~= nil
	local cur = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local prev = s.prev or cur
	write_file(prevfile, table.concat(prev, "\n") .. "\n")
	s.prev = cur

	local rel = vim.fs.relpath(info.root, file) or file
	log.info("run", {
		file = rel, runid = runid, model = cfg.model,
		had_prev = had_prev, prev_lines = #prev, cur_lines = #cur,
		empty_diff = had_prev and table.concat(prev, "\n") == table.concat(cur, "\n"),
	})

	local args = {
		cfg.claude_cmd, "-p",
		("/wake-stream %s %s %s"):format(rel, runid, prevfile),
		"--allowedTools", "Bash", "Read", "Grep", "Glob",
		"--model", cfg.model,
		"--permission-mode", "acceptEdits",
	}
	local env = vim.tbl_extend("force", vim.fn.environ(), { WAKE_DISABLE = "1" })

	store.active = store.active + 1
	start_spinner()
	render.indicator()

	s.job = vim.system(args, { cwd = info.root, env = env, text = true, stdin = "" }, vim.schedule_wrap(function(res)
		s.job = nil
		store.active = math.max(0, store.active - 1)
		stop_spinner()
		store.last_stdout = res.stdout
		log.info("exit", { code = res.code, runid = runid })
		log.debug("patcher stdout", (res.stdout or "(empty)"):gsub("%s+$", ""))
		if res.code ~= 0 then
			store.last_error = ("patcher exited %d\n\n--- stderr ---\n%s\n--- stdout ---\n%s")
				:format(res.code, res.stderr or "(empty)", res.stdout or "(empty)")
			log.error("patcher failed", { code = res.code, stderr = res.stderr })
			if cfg.notify then
				vim.notify("wake: patcher failed (exit " .. res.code .. "). :WakeError for details", vim.log.levels.WARN)
			end
			render.indicator()
			return
		end
		local ok = ingest(info, rel, runid)
		if not ok and cfg.notify then
			vim.notify("wake: patcher produced no usable queue. :WakeError for details", vim.log.levels.WARN)
		end
		refresh()
	end))
end

return M
