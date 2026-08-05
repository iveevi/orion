require('config.lazy')

vim.cmd [[ colorscheme nord ]]

vim.opt.laststatus = 3

vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = '↳ '

vim.opt.tabstop = 8
vim.opt.shiftwidth = 8
vim.opt.expandtab = false

vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('FileTypeSettings', { clear = true }),
	callback = function(args)
		local filetype = args.match
    if filetype == 'lua' then
			vim.bo.tabstop = 2
			vim.bo.shiftwidth = 2
			vim.bo.expandtab = true
    elseif filetype == 'cup' then
			vim.bo.tabstop = 4
			vim.bo.shiftwidth = 4
		end
	end,
})

vim.opt.foldmethod = 'manual'

-- Auto-reload files changed outside of neovim
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
	callback = function()
		if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
			vim.cmd('checktime')
		end
	end,
})

-- Macros disabled
vim.keymap.set({ 'n', 'x' }, 'q', '<Nop>', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'x' }, '@', '<Nop>', { noremap = true, silent = true })

-- Toggling comments
vim.keymap.set('n', 'cc', 'gcc', { remap = true, desc = 'Toggle line comment' })
vim.keymap.set('v', 'cc', 'gc', { remap = true, desc = 'Toggle selection comment' })

-- LSP configuration
vim.lsp.enable('clangd')
vim.lsp.enable('pyright')
vim.lsp.enable('marksman')
vim.lsp.enable('rust-analyzer')
vim.lsp.enable('tinymist')
vim.lsp.enable('slangd')

vim.lsp.config('slangd', {
	settings = {
		slang = {
			inlayHints = {
				deducedTypes = true,
				parameterNames = true,
			},
		},
	},
})

-- Saving files
vim.keymap.set(
	{ 'i', 'v', 'n', 't' }, '<C-s>',
	'<cmd>w<cr>',
{ noremap = true, silent = true })

-- File tree
vim.keymap.set(
	{ 'i', 'v', 'n', 't' }, '<C-e>',
	function()
		vim.cmd [[ Yazi ]]
	end,
{ noremap = true, silent = true })

-- File searches
vim.keymap.set(
	{ 'i', 'v', 'n', 't' },
	'<C-p>', '<cmd>Telescope find_files<cr>',
	{ noremap = true, silent = true }
)

-- Active buffer searches
vim.keymap.set(
	{ 'i', 'v', 'n', 't' },
	'<C-l>', '<cmd>Telescope buffers<cr>',
	{ noremap = true, silent = true }
)

-- Grep searcher
vim.keymap.set(
	{ 'i', 'v', 'n', 't' },
	'<C-g>', '<cmd>Telescope live_grep<cr>',
	{ noremap = true, silent = true }
)

-- Toggling the central terminal
vim.keymap.set(
	{ 'i', 'v', 'n', 't' }, '<C-`>',
	'<cmd>1ToggleTerm direction=float<cr>',
{ noremap = true, silent = true })

-- Toggling the horizontal terminal
vim.keymap.set(
	{ 'i', 'v', 'n', 't' }, '<C-1>',
	'<cmd>2ToggleTerm direction=vertical size=80<cr>',
{ noremap = true, silent = true })

-- Refactoring
vim.keymap.set({ 'i', 'n' }, '<C-r>', vim.lsp.buf.rename)

-- Go to definition
vim.keymap.set({ 'i', 'n' }, 'gd', vim.lsp.buf.definition)

-- Diff view management
vim.g.diffview = false

vim.keymap.set({ 'n', 't', 'v' }, '<C-d>',
	function()
		if vim.g.diffview then
			vim.cmd [[ DiffviewClose ]]
		else
			vim.cmd [[ DiffviewOpen ]]
		end

		vim.g.diffview = not vim.g.diffview
	end,
{ noremap = true, silent = true})

-- Session managing
vim.keymap.set(
	{ 'n', 'v', 'o' }, 's',
	'<Nop>',
{ noremap = true, silent = true })

vim.keymap.set(
	{ 'n', 'v', 'o' }, 'ss',
	function()
		vim.cmd [[ Telescope session-lens ]]
	end,
{ noremap = true, silent = true })

vim.cmd [[ highlight NormalFloat guibg=None ctermbg=None ]]
vim.cmd [[ highlight FloatBorder guibg=None ctermbg=None ]]

-- Copy pasting overrides
vim.api.nvim_set_keymap('v', '<sc-c>', '"+y', { noremap = true })
vim.api.nvim_set_keymap('i', '<sc-v>', '<ESC>"+p', { noremap = true })
vim.api.nvim_set_keymap('n', '<sc-v>', '"+p', { noremap = true })

-- Arrow keys move by screen line when wrapped, but keep linewise semantics when
-- given a count so that 5<Down> still jumps five real lines.
vim.keymap.set({ 'n', 'x' }, '<Down>', function()
	return vim.v.count == 0 and 'gj' or 'j'
end, { expr = true, silent = true })

vim.keymap.set({ 'n', 'x' }, '<Up>', function()
	return vim.v.count == 0 and 'gk' or 'k'
end, { expr = true, silent = true })

vim.keymap.set({ 'n', 'x' }, '<Home>', 'g<Home>', { silent = true })
vim.keymap.set({ 'n', 'x' }, '<End>', 'g<End>', { silent = true })

vim.keymap.set('i', '<Down>', '<C-o>gj', { silent = true })
vim.keymap.set('i', '<Up>', '<C-o>gk', { silent = true })
vim.keymap.set('i', '<Home>', '<C-o>g<Home>', { silent = true })
vim.keymap.set('i', '<End>', '<C-o>g<End>', { silent = true })
