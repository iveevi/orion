-- wake.nvim — stream mode (preview): on save, a headless patcher proposes
-- continuation diffs across the repo; browse them in a panel and preview inline.
-- No apply/commit yet.
local state = require("wake.state")
local paths = require("wake.paths")
local render = require("wake.render")
local store = require("wake.store")
local panel = require("wake.panel")
local job = require("wake.job")
local log = require("wake.log")

local M = {}

M.config = {
	enabled = true,
	model = "haiku", -- patcher model (testing default)
	claude_cmd = "claude",
	spinner_ms = 80,
	notify = true,
	statusline = true,
	log = true,
	log_level = "debug",
	debounce_ms = 50,
	keymaps = {
		panel = "<leader>ww", -- toggle the diff panel
	},
}

function M.statusline()
	return render.chip()
end

function M.show_error()
	local e = store.last_error
	if not e or e == "" then
		vim.notify("wake: no recent error", vim.log.levels.INFO)
		return
	end
	vim.lsp.util.open_floating_preview(vim.split(e, "\n", { plain = true }), "", {
		border = "rounded", max_width = 110, max_height = 25, wrap = true,
	})
end

function M.clear()
	store.clear()
	render.refresh_visible()
	panel.render()
	render.indicator()
end

local function active(buf)
	if not M.config.enabled then return false end
	if not vim.api.nvim_buf_is_valid(buf) then return false end
	if vim.bo[buf].buftype ~= "" then return false end
	if not vim.bo[buf].modifiable then return false end
	return true
end

function M.run(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not active(buf) then return end
	job.run(buf)
end

function M.toggle()
	M.config.enabled = not M.config.enabled
	vim.notify("wake stream mode: " .. (M.config.enabled and "on" or "off"))
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	log.setup(M.config)
	log.info("setup", { model = M.config.model, log_level = M.config.log_level })
	job.init(M.config)
	render.setup_hl()

	local grp = vim.api.nvim_create_augroup("wake", { clear = true })

	local function snapshot_prev(buf)
		if not active(buf) then return end
		if not paths.root(vim.api.nvim_buf_get_name(buf)) then return end
		local s = state.get(buf)
		if not s.prev then s.prev = vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
	end

	-- Snapshot a baseline and draw any pending overlays when a file appears.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		group = grp,
		callback = function(a)
			snapshot_prev(a.buf)
			render.overlays(a.buf)
		end,
	})
	snapshot_prev(vim.api.nvim_get_current_buf())

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = grp,
		callback = function(a) M.run(a.buf) end,
	})

	vim.api.nvim_create_autocmd("ColorScheme", { group = grp, callback = render.setup_hl })

	-- Re-anchor overlays as the buffer changes (drift / staleness).
	local rtimer = vim.uv.new_timer()
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = grp,
		callback = function(a)
			if store.count() == 0 then return end
			rtimer:stop()
			rtimer:start(M.config.debounce_ms, 0, vim.schedule_wrap(function()
				if vim.api.nvim_buf_is_valid(a.buf) then render.overlays(a.buf) end
			end))
		end,
	})

	if M.config.keymaps.panel then
		vim.keymap.set("n", M.config.keymaps.panel, panel.toggle, { silent = true, desc = "wake: toggle diff panel" })
	end

	for name, fn in pairs({
		WakePanel = panel.toggle,
		WakeRun = M.run,
		WakeToggle = M.toggle,
		WakeClear = M.clear,
		WakeError = M.show_error,
		WakeLog = log.open,
		WakeLogClear = log.clear,
	}) do
		vim.api.nvim_create_user_command(name, function() fn() end, {})
	end

	if M.config.statusline and not vim.o.statusline:find("require'wake'.statusline", 1, true) then
		local chip = "%{%v:lua.require'wake'.statusline()%}"
		if vim.o.statusline == "" then
			vim.o.statusline = "%<%f %h%m%r%=" .. chip .. "  %-14.(%l,%c%V%) %P"
		else
			vim.o.statusline = vim.o.statusline .. " " .. chip
		end
	end
end

return M
