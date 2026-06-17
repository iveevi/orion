-- Side panel listing all proposed diffs, grouped by file. Preview only:
-- <CR> opens the target file and renders the inline overlay; no apply.
local store = require("wake.store")
local patch = require("wake.patch")
local render = require("wake.render")

local M = { win = nil, buf = nil, line_map = {} }

function M.is_open()
	return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

-- A usable window to preview in (not the panel). Create a split if needed.
local function target_win()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if w ~= M.win and vim.api.nvim_win_get_config(w).relative == "" then
			return w
		end
	end
	vim.cmd("topleft vsplit")
	return vim.api.nvim_get_current_win()
end

function M.render()
	if not M.is_open() then return end
	local lines, hl, map = {}, {}, {}
	local n = store.count()
	lines[#lines + 1] = n == 0 and "  no diffs yet" or ("  " .. n .. " diff" .. (n == 1 and "" or "s"))
	hl[#hl + 1] = { 0, "WakePanelFile" }

	-- group by file, preserving first-seen order
	local order, groups = {}, {}
	for _, d in ipairs(store.diffs) do
		if not groups[d.file_rel] then groups[d.file_rel] = {}; order[#order + 1] = d.file_rel end
		table.insert(groups[d.file_rel], d)
	end
	for _, rel in ipairs(order) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = rel .. "  (" .. #groups[rel] .. ")"
		hl[#hl + 1] = { #lines - 1, "WakePanelFile" }
		for _, d in ipairs(groups[rel]) do
			lines[#lines + 1] = "   • " .. (d.why ~= "" and d.why or "(no description)")
			map[#lines] = d
		end
	end

	vim.bo[M.buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
	vim.bo[M.buf].modifiable = false
	local ns = vim.api.nvim_create_namespace("wake-panel")
	vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
	for _, h in ipairs(hl) do
		vim.api.nvim_buf_set_extmark(M.buf, ns, h[1], 0, { line_hl_group = h[2] })
	end
	M.line_map = map
end

function M.preview()
	local d = M.line_map[vim.api.nvim_win_get_cursor(M.win)[1]]
	if not d then return end
	local win = target_win()
	vim.api.nvim_set_current_win(win)
	vim.cmd("edit " .. vim.fn.fnameescape(d.file_abs))
	local buf = vim.api.nvim_get_current_buf()
	render.overlays(buf)
	local sr = patch.range(buf, d)
	if sr then
		vim.api.nvim_win_set_cursor(win, { sr + 1, 0 })
		vim.cmd("normal! zz")
	else
		vim.notify("wake: this diff no longer anchors in " .. d.file_rel, vim.log.levels.INFO)
	end
end

function M.open()
	if M.is_open() then return end
	M.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[M.buf].filetype = "wakepanel"
	vim.bo[M.buf].bufhidden = "wipe"
	vim.cmd("botright vsplit")
	M.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(M.win, M.buf)
	vim.api.nvim_win_set_width(M.win, 44)
	local wo = vim.wo[M.win]
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.wrap = false
	wo.cursorline = true
	wo.winfixwidth = true

	local function kmap(lhs, fn) vim.keymap.set("n", lhs, fn, { buffer = M.buf, nowait = true, silent = true }) end
	kmap("<CR>", M.preview)
	kmap("q", M.close)
	kmap("R", function() store.clear(); render.refresh_visible(); M.render(); render.indicator() end)

	M.render()
end

function M.close()
	if M.is_open() then vim.api.nvim_win_close(M.win, true) end
	M.win, M.buf, M.line_map = nil, nil, {}
end

function M.toggle()
	if M.is_open() then M.close() else M.open() end
end

return M
