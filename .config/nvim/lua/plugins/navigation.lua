return {
	-- {
	-- 	'nvim-neo-tree/neo-tree.nvim',
	-- 	dependencies = {
	-- 		'nvim-lua/plenary.nvim',
	-- 		'nvim-tree/nvim-web-devicons',
	-- 		'MunifTanjim/nui.nvim',
	-- 	},
	-- 	config = function()
	-- 		require('neo-tree').setup {
	-- 			filesystem = {
	-- 				window = {
	-- 					mappings = {
	-- 						['o'] = 'system_open',
	-- 					},
	-- 				},
	-- 				filtered_items = {
	-- 					visible = true,
	-- 					hide_dotfiles = false,
	-- 					hide_gitignored = false,
	-- 				},
	-- 			},
	-- 			commands = {
	-- 				system_open = function(state)
	-- 					local node = state.tree:get_node()
	-- 					local path = node:get_id()
	-- 					vim.fn.jobstart({ 'xdg-open', path }, { detach = true })
	-- 				end,
	-- 			},
	-- 		}
	-- 	end,
	-- },

	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
		},
	},

	{
		'karb94/neoscroll.nvim',
		opts = {},
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
