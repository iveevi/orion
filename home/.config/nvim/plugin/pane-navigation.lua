-- Mode-preserving pane navigation
local win_mode = {}
local function stamp(m)
	win_mode[vim.api.nvim_get_current_win()] = m
end

vim.api.nvim_create_autocmd('InsertEnter', { callback = function() stamp('i') end })
vim.api.nvim_create_autocmd('InsertLeave', { callback = function() stamp('n') end })
vim.api.nvim_create_autocmd('TermEnter', { callback = function() stamp('t') end })
vim.api.nvim_create_autocmd('TermLeave', { callback = function() stamp('n') end })
vim.api.nvim_create_autocmd('WinClosed', {
	callback = function(ev) win_mode[tonumber(ev.match)] = nil end,
})

local function go(dir)
	local cur = vim.api.nvim_get_current_win()
	local target = vim.fn.win_getid(vim.fn.winnr('1' .. dir))
	if target == 0 or target == cur then return end
	vim.api.nvim_set_current_win(target)
	local m = win_mode[target]
	vim.schedule(function()
		if vim.api.nvim_get_current_win() ~= target then return end
		if m == 'i' or m == 't' then
			vim.cmd.startinsert()
		else
			vim.cmd.stopinsert()
		end
	end)
end

for _, a in ipairs({ 'Up', 'Down', 'Left', 'Right' }) do
	local dir = ({ Up = 'k', Down = 'j', Left = 'h', Right = 'l' })[a]
	for _, mode in ipairs({ 'n', 'i', 't' }) do
		vim.keymap.set(mode, '<S-' .. a .. '>', function() go(dir) end, { silent = true })
	end
end
