require("polish").setup({})

vim.keymap.set("x", "gp1", function()
	require("polish").polish(1)
end, { desc = "Polish selection (conservative)" })

vim.keymap.set("x", "gp2", function()
	require("polish").polish(2)
end, { desc = "Polish selection (rewrite)" })

vim.keymap.set("x", "gpx", function()
	require("polish").ask_polish(3)
end, { desc = "Polish selection (custom instruction, opus)" })

vim.keymap.set("x", "gpy", function()
	require("polish").ask_polish(4)
end, { desc = "Freeform prompt on selection (opus)" })

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		vim.defer_fn(function()
			require("polish").warm()
		end, 500)
	end,
})
