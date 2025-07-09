require("config.lazy")

vim.cmd [[ colorscheme onenord ]]

vim.opt.laststatus = 3
vim.opt.wrap = false

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
	'<C-l>', '<cmd>Telescope live_grep<cr>',
	{ noremap = true, silent = true }
)
