return {
	{
		'b0o/incline.nvim',
		config = function()
			local helpers = require('incline.helpers')
			local devicons = require('nvim-web-devicons')

			require('incline').setup {
				window = {
					padding = 0,
					margin = { horizontal = 0 },
				},
				render = function(props)
					local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ':t')
					if filename == '' then
						filename = '[No Name]'
					end
					local ft_icon, ft_color = devicons.get_icon_color(filename)
					local modified = vim.bo[props.buf].modified
					return {
						ft_icon and { ' ', ft_icon, ' ', guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or '',
						' ',
						{ filename, gui = modified and 'bold,italic' or 'bold' },
						' ',
						guibg = '#4c566a',
					}
				end,
			}
		end,
	},

	{
		'nvim-tree/nvim-web-devicons',
	},

	{
		'folke/todo-comments.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' },
		config = function()
			require('todo-comments').setup {}
		end,
	},

	{
		'echasnovski/mini.nvim',
		version = '*',
	},

	{
		'romgrk/barbar.nvim',
		dependencies = {
			'nvim-tree/nvim-web-devicons',
		},
		init = function() vim.g.barbar_auto_setup = false end,
		opts = {},
	},

	{
		'lukas-reineke/indent-blankline.nvim',
		config = function()
			require('ibl').setup {}
		end,
	},

	{
		'MunifTanjim/nui.nvim',
	},

	{
		'folke/zen-mode.nvim',
	},
}
