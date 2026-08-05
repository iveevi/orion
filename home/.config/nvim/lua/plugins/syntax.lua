return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		build = ':TSUpdate',
		lazy = false,
		config = function()
			-- start highlighting per-buffer; main branch has no `highlight.enable`
			vim.api.nvim_create_autocmd('FileType', {
        pattern = {
          'cpp', 'lua', 'vim', 'help', 'glsl', 'markdown', 'slang', 'python',
          'wgsl', 'typst', 'shaderslang',
        },
				callback = function()
					pcall(vim.treesitter.start)
				end,
			})
		end,
	},

  {
    dir = vim.fn.expand('~/projects/porcelain/porcelain/nvim/'),
    ft = "por",
  },
  
  -- {
  --   dir = vim.fn.expand('~/projects/cupric/source/nvim/'),
  --   ft = "cup",
  -- },
}
