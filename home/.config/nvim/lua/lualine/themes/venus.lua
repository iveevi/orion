local bg = "#141417"
local plate = "#202024"
local seam = "#353538"
local ink = "#a9aea8"
local faint = "#6f7873"
local string_color = "#7bb68d"
local func = "#5f9a92"
local keyword = "#538a97"
local flow = "#bd6c63"
local amber = "#ab7c52"

local function mode(color)
	return {
		a = { fg = bg, bg = color, gui = "bold" },
		b = { fg = ink, bg = plate },
		c = { fg = faint, bg = bg },
	}
end

return {
	normal = mode(keyword),
	insert = mode(string_color),
	visual = mode(func),
	replace = mode(flow),
	command = mode(amber),
	inactive = {
		a = { fg = faint, bg = plate },
		b = { fg = faint, bg = bg },
		c = { fg = seam, bg = bg },
	},
}
