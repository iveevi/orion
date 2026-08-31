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
    dir = vim.fn.expand('~/projects/porcelain/editors/nvim/'),
    name = 'porcelain-nvim',
  },
  
  {
    dir = vim.fn.expand('~/projects/cupric/editors/nvim/'),
    name = 'cupric-nvim',
  },
  
  {
    dir = vim.fn.expand('~/projects/icandi/editors/nvim/'),
    name = 'icandi-nvim',
  },
}
