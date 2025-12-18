return {
	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
		},
		config = function()
			local actions = require('telescope.actions')
			require('telescope').setup {
				defaults = {
					mappings = {
						i = {
							['esc'] = actions.close,
						},
					},
				},
				pickers = {
					buffers = {
						sort_mru = true,
					},
				},
			}
		end,
	},

	{
		'karb94/neoscroll.nvim',
		opts = {},
	},

	{
		'sindrets/diffview.nvim',
	},

	{
		'rmagatti/auto-session',
		config = function()
			require('auto-session').setup {
				supress_dirs = { '~/', },
			}
		end,
	},

	{
		'mikavilpas/yazi.nvim',
		config = function()
			require('yazi').setup {
				use_ya_for_events_reading = true,
				highlight_groups = {
					hovered_buffer = { bg = "None" },
				},
				floating_window_scaling_factor = 0.75,
			}
		end,
	},
}
