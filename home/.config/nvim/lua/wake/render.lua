-- Inline preview overlays (signs, deleted-line hl, virtual added lines) for the
-- diffs targeting a given buffer's file, plus the statusline chip. Preview only.
local store = require("wake.store")
local patch = require("wake.patch")
local log = require("wake.log")

local M = {}
local NS = vim.api.nvim_create_namespace("wake")
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.setup_hl()
	local function link(name, to) vim.api.nvim_set_hl(0, name, { link = to, default = true }) end
	link("WakeOld", "DiffDelete")
	link("WakeNew", "DiffAdd")
	link("WakeSign", "DiffText")
	link("WakeProcessing", "DiagnosticWarn")
	link("WakeReady", "DiagnosticOk")
	link("WakeError", "DiagnosticError")
	link("WakePanelFile", "Title")
	link("WakePanelWhy", "Normal")
end

-- Draw overlays for every store diff that targets this buffer's file and still
-- anchors uniquely. Returns the number drawn.
function M.overlays(buf)
	if not vim.api.nvim_buf_is_valid(buf) then return 0 end
	vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
	local abs = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
	local drawn, dropped = 0, 0
	for _, d in ipairs(store.for_file(abs)) do
		local sr, er = patch.range(buf, d)
		if sr then
			drawn = drawn + 1
			vim.api.nvim_buf_set_extmark(buf, NS, sr, 0, { sign_text = "~", sign_hl_group = "WakeSign" })
			for r = sr, er do
				vim.api.nvim_buf_set_extmark(buf, NS, r, 0, { line_hl_group = "WakeOld" })
			end
			local virt = {}
			for _, line in ipairs(d.new_lines) do
				virt[#virt + 1] = { { line ~= "" and line or " ", "WakeNew" } }
			end
			if #virt > 0 then
				vim.api.nvim_buf_set_extmark(buf, NS, er, 0, { virt_lines = virt, virt_lines_above = false })
			end
		else
			dropped = dropped + 1
		end
	end
	if drawn + dropped > 0 then
		log.debug("overlays", { file = abs, drawn = drawn, dropped = dropped })
	end
	return drawn
end

-- Redraw overlays in every window currently showing a file.
function M.refresh_visible()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_get_name(b) ~= "" then M.overlays(b) end
	end
end

function M.clear(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
	end
end

-- Statusline chip from the aggregate store state.
function M.chip()
	local st = store.status()
	if st == "processing" then
		return "%#WakeProcessing#" .. SPINNER[store.frame] .. " wake " .. store.count() .. "%*"
	elseif st == "ready" then
		return "%#WakeReady#● wake " .. store.count() .. "%*"
	end
	return ""
end

function M.indicator()
	pcall(vim.cmd.redrawstatus)
end

function M.tick()
	store.frame = (store.frame % #SPINNER) + 1
	M.indicator()
end

return M
