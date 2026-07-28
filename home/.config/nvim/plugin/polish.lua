require("polish").setup({})

vim.keymap.set("x", "gp1", function()
	require("polish").polish(1)
end, { desc = "Polish selection (conservative)" })

vim.keymap.set("x", "gp2", function()
	require("polish").polish(2)
end, { desc = "Polish selection (rewrite)" })

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		vim.defer_fn(function()
			require("polish").warm()
		end, 500)
	end,
})
