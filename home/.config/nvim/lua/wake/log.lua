-- Lightweight file logger for diagnosing the stream pipeline.
local M = {
	path = vim.fn.stdpath("state") .. "/wake.log",
	level = "debug",
	enabled = true,
}
local ORDER = { debug = 1, info = 2, warn = 3, error = 4 }

function M.setup(opts)
	M.enabled = opts.log ~= false
	M.level = opts.log_level or M.level
end

local function write(line)
	local f = io.open(M.path, "a")
	if f then f:write(line .. "\n"); f:close() end
end

function M.log(lvl, msg, data)
	if not M.enabled then return end
	if ORDER[lvl] < ORDER[M.level] then return end
	local line = ("[%s] %-5s %s"):format(os.date("%H:%M:%S"), lvl:upper(), msg)
	if data ~= nil then
		line = line .. "  " .. (type(data) == "table"
			and vim.inspect(data, { newline = " ", indent = "" })
			or tostring(data))
	end
	write(line)
end

function M.debug(m, d) M.log("debug", m, d) end
function M.info(m, d) M.log("info", m, d) end
function M.warn(m, d) M.log("warn", m, d) end
function M.error(m, d) M.log("error", m, d) end

function M.open()
	local lines = {}
	local f = io.open(M.path, "r")
	if f then
		for l in f:lines() do lines[#lines + 1] = l end
		f:close()
	end
	if #lines == 0 then lines = { "(wake log empty: " .. M.path .. ")" } end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "log"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local w = math.floor(vim.o.columns * 0.85)
	local h = math.floor(vim.o.lines * 0.8)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		style = "minimal",
		border = "rounded",
		title = " wake log ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
	vim.api.nvim_win_set_cursor(win, { #lines, 0 })
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = buf, nowait = true, silent = true })
end

function M.clear()
	local f = io.open(M.path, "w")
	if f then f:close() end
	vim.notify("wake: log cleared (" .. M.path .. ")")
end

return M
