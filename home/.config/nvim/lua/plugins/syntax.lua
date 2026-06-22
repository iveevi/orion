return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		build = ':TSUpdate',
		lazy = false,
		config = function()
			local langs = {
				'cpp', 'lua', 'vim', 'vimdoc',
				'glsl', 'markdown', 'markdown_inline',
        'slang',
			}
			require('nvim-treesitter').install(langs)
			-- start highlighting per-buffer; main branch has no `highlight.enable`
			vim.api.nvim_create_autocmd('FileType', {
				pattern = { 'cpp', 'lua', 'vim', 'help', 'glsl', 'markdown', 'slang', 'python', },
				callback = function()
					pcall(vim.treesitter.start)
				end,
			})
		end,
	},

  {
    dir = vim.fn.expand('~/projects/porcelain/porcelain/nvim/'),
  },
}
