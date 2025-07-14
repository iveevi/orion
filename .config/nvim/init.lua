require('config.lazy')

vim.cmd [[ colorscheme onenord ]]

vim.opt.laststatus = 3
vim.opt.wrap = false

-- LSP configuration
vim.lsp.enable('clangd')
vim.lsp.enable('pyright')

-- Saving files
vim.keymap.set(
	{ 'i', 'v', 'n', 't' },
	'<C-s>', '<cmd>w<cr>',
	{ noremap = true, silent = true }
)

-- File tree
vim.keymap.set(
	{ 'i', 'v', 'n', 't' },
	'<C-e>', '<cmd>Neotree toggle<cr>',
	{ noremap = true, silent = true }
)

-- File searcher
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
	{ 'i', 'v', 'n', 't' },
	'<C-`>', '<cmd>ToggleTerm direction=float<cr>',
	{ noremap = true, silent = true }
)
