return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'master',
		build = ':TSUpdate',
		lazy = false,
		config = function()
			require('nvim-treesitter.configs').setup {
				ensure_installed = {
					'cpp', 'lua', 'vim', 'vimdoc',
					'glsl', 'markdown', 'markdown_inline',
				},
				highlight = { enable = true },
				indent = { enable = false },
			}
		end,
	},
}
