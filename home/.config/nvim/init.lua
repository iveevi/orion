require('config.lazy')

vim.cmd [[ colorscheme nordfox ]]

vim.opt.laststatus = 3
vim.opt.wrap = false

vim.opt.tabstop = 8
vim.opt.shiftwidth = 8
vim.opt.expandtab = false

vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('FileTypeSettings', { clear = true }),
	callback = function(args)
		local filetype = args.match
     if filetype == 'axel' then
			vim.bo.tabstop = 4
			vim.bo.shiftwidth = 4
			vim.bo.expandtab = false
    elseif filetype == 'lua' then
			vim.bo.tabstop = 2
			vim.bo.shiftwidth = 2
			vim.bo.expandtab = true
		end
	end,
})

vim.filetype.add({
  extension = {
    axel = 'axel',
  },
})

vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

vim.opt.sessionoptions:remove('options')

-- LSP configuration
vim.lsp.enable('clangd')
vim.lsp.enable('pyright')
vim.lsp.enable('marksman')

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

-- Escaping out of terminals
vim.keymap.set(
	{ 't' },
	'<esc>', '<C-\\><C-n>',
	{ noremap = true, silent = true }
)

-- Toggling the central terminal
vim.keymap.set(
	{ 'i', 'v', 'n', 't' }, '<C-`>',
	'<cmd>ToggleTerm direction=float<cr>',
{ noremap = true, silent = true })

-- Hover window
vim.keymap.set(
	'n', 'hh',
	function()
		require('hover').open()
	end
)

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

-- For LateX files
vim.api.nvim_create_autocmd('FileType', {
	pattern = { 'tex', 'plaintex' },
	callback = function()
		vim.opt.wrap = true
		vim.opt.breakindent = true
	end,
})
