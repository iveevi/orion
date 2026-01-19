return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'master',
		config = function() 
			require('nvim-treesitter.configs').setup {
				ensure_installed = {
					'cpp', 'lua', 'vim',
				},
				highlight = {
					enable = true
				},
				indent = {
					enable = false
				},
			}
		end
	},

	{
		'numToStr/Comment.nvim',
		opts = {
			toggler = {
				line = 'cc',
				block = 'cb',
			},
			opleader = {
				line = 'cc',
				block = 'cb',
			},
		},
	},
}
