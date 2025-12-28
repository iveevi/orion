return {
	{
		'akinsho/toggleterm.nvim',
		config = function()
			require('toggleterm').setup {
				shade_terminals = false,
				float_opts = {
					border = 'curved',
				},
			}
		end,
	},

	{
		'google/executor.nvim',
		config = function()
			require('executor').setup {
				use_split = false,
			}
		end,
	},
}
