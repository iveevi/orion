return {
	{
		'neovim/nvim-lspconfig',
	},

	{
		'folke/trouble.nvim',
		options = {},
		cmd = 'Trouble',
		config = function()
			require('trouble').setup {}
		end,
	},

	{
		'onsails/lspkind.nvim',
		config = function()
			require('lspkind').setup {}
		end,
	},

	{
		'lewis6991/hover.nvim',
		config = function()
			require('hover').config {
				preview_opts = {
					border = 'rounded',
				},
			}
		end,
	},

	{
		'saghen/blink.cmp',
		version = '1.*',
		config = function()
			require('blink.cmp').setup {
				completion = {
					menu = {
						border = 'rounded',
						draw = {
							components = {
								kind_icon = {
									text = function(ctx)
										local icon = ctx.kind_icon
										if vim.tbl_contains({ "Path" }, ctx.source_name) then
											local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label)
											if dev_icon then
												icon = dev_icon
											end
										else
											-- icon = require("lspkind").symbolic(ctx.kind, {
											-- 	mode = "symbol",
											-- })
										end

										return icon .. ctx.icon_gap
									end,

									-- Optionally, use the highlight groups from nvim-web-devicons
									-- You can also add the same function for `kind.highlight` if you want to
									-- keep the highlight groups in sync with the icons.
									highlight = function(ctx)
										local hl = ctx.kind_hl
										if vim.tbl_contains({ "Path" }, ctx.source_name) then
											local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
											if dev_icon then
												hl = dev_hl
											end
										end
										return hl
									end,
								}
							}
						},
					},
					documentation = {
						window = {
							border = 'rounded'
						}
					},
					ghost_text = {
						enabled = true,
					},
				},
			}
		end,
	},
}
