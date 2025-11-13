return {
	{
		'everviolet/nvim',
		name = 'evergarden',
		priority = 1000,
		opts = {
			theme = {
				variant = 'spring',
				accent = 'red',
			},
			editor = {
				transparent_background = false,
				sign = { color = 'none' },
				float = {
					color = 'mantle',
					solid_border = false,
				},
				completion = {
					color = 'surface0',
				},
			},
		}
	},

	{
		'neanias/everforest-nvim',
	},

	{
		'rktjmp/lush.nvim',
	},
}
