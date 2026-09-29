return {
	{
		'nvim-lualine/lualine.nvim',
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		config = function()
			local function lsp_clients()
				local names = {}
				for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
					table.insert(names, client.name)
				end

				if #names == 0 then
					return ''
				end

				return ' ' .. table.concat(names, ' ')
			end

			require('lualine').setup {
				options = {
					theme = 'venus',
					globalstatus = true,
					section_separators = { left = '', right = '' },
					component_separators = { left = '', right = '' },
				},
				sections = {
					lualine_a = { 'mode' },
					lualine_b = {},
					lualine_c = {
						{ 'filename', path = 1, symbols = { modified = ' ', readonly = ' ', unnamed = '[No Name]' } },
						'searchcount',
						'selectioncount',
					},
					lualine_x = {
						{
							'diagnostics',
							symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
						},
						lsp_clients,
						'filetype',
					},
					lualine_y = { 'progress' },
					lualine_z = { 'location' },
				},
				extensions = { 'lazy', 'toggleterm', 'trouble' },
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
		config = function()
			require('mini.git').setup()
		end,
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
		'MeanderingProgrammer/render-markdown.nvim',
		dependencies = {
			'nvim-treesitter/nvim-treesitter',
			'nvim-tree/nvim-web-devicons'
		},
		opts = {},
	},

	{
		'xiyaowong/transparent.nvim',
		lazy = false,
		priority = 1000,
		config = function()
			require('transparent').setup {}
			vim.g.transparent_enabled = true
		end,
	},
}
