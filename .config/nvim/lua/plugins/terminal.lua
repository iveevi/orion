return {
	{
		'akinsho/toggleterm.nvim',
		config = true,
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
