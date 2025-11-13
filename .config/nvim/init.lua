require('config.lazy')

-- For Neovide
vim.g.neovide_floating_shadow = false
vim.o.guifont = 'IosevkaTerm Nerd Font Mono:h22'
vim.g.neovide_cursor_trail_size = 0

vim.cmd [[ set background=light]]
vim.cmd [[ colorscheme everforest ]]

vim.opt.laststatus = 3
vim.opt.wrap = false

-- LSP configuration
vim.lsp.enable('clangd')
vim.lsp.enable('pyright')

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
	end,
{ desc = 'hover.nvim (open)' })

-- Refactoring
vim.keymap.set(
	{ 'i', 'n' }, '<C-r>',
	vim.lsp.buf.rename,
{ desc = 'hover.nvim (open)' })

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

-- TODO: lua-ify
vim.cmd [[ highlight FloatBorder guibg=None ctermbg=None ]]

-- Copy pasting overrides
vim.api.nvim_set_keymap('v', '<sc-c>', '"+y', { noremap = true })
vim.api.nvim_set_keymap('i', '<sc-v>', '<ESC>"+p', { noremap = true })
vim.api.nvim_set_keymap('n', '<sc-v>', '"+p', { noremap = true })
