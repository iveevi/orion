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
					}
				end,
			}
		end,
	},

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

			local ahead_behind = {}

			local function refresh_ahead_behind(root)
				if root == nil then
					return
				end

				vim.system(
					{ 'git', 'rev-list', '--left-right', '--count', '@{upstream}...HEAD' },
					{ cwd = root, text = true },
					function(result)
						local behind, ahead = (result.stdout or ''):match('(%d+)%s+(%d+)')
						ahead_behind[root] = { ahead = tonumber(ahead) or 0, behind = tonumber(behind) or 0 }
						vim.schedule(function()
							vim.cmd('redrawstatus')
						end)
					end
				)
			end

			local function git_state()
				local summary = vim.b.minigit_summary
				if summary == nil or summary.head_name == nil then
					return ''
				end

				local parts = {}
				local counts = ahead_behind[summary.root]
				if counts ~= nil then
					if counts.ahead > 0 then
						table.insert(parts, ' ' .. counts.ahead)
					end

					if counts.behind > 0 then
						table.insert(parts, ' ' .. counts.behind)
					end
				end

				local status = summary.status or ''
				if status == '??' then
					table.insert(parts, '')
				else
					if status:sub(1, 1):match('%S') then
						table.insert(parts, '')
					end

					if status:sub(2, 2):match('%S') then
						table.insert(parts, '')
					end
				end

				if summary.in_progress ~= nil and summary.in_progress ~= '' then
					table.insert(parts, ' ' .. summary.in_progress)
				end

				return table.concat(parts, ' ')
			end

			require('lualine').setup {
				options = {
					theme = 'nord',
					globalstatus = true,
					section_separators = { left = '', right = '' },
					component_separators = { left = '', right = '' },
				},
				sections = {
					lualine_a = { 'mode' },
					lualine_b = {
						{ 'branch', icon = '' },
						{
							'diff',
							symbols = { added = ' ', modified = ' ', removed = ' ' },
						},
						git_state,
					},
					lualine_c = { 'searchcount', 'selectioncount' },
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

			vim.api.nvim_create_autocmd('User', {
				pattern = 'MiniGitUpdated',
				group = vim.api.nvim_create_augroup('LualineGitState', { clear = true }),
				callback = function(args)
					local summary = vim.b[args.buf].minigit_summary
					if summary ~= nil then
						refresh_ahead_behind(summary.root)
					end
				end,
			})
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
	}
}
