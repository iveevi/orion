-- wake.nvim (stream mode) — local plugin, modules live in lua/wake/.
-- Auto-sourced at startup; no plugin manager needed.
require("wake").setup({
	enabled = false, -- off by default; toggle with :WakeToggle
	model = "haiku", -- patcher model (testing)
})
