-- Locate, apply, and reject line-granular search/replace patches.
local M = {}

local function split_lines(s)
	-- Normalize and split into a list of complete lines (no trailing empty).
	s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
	local out = {}
	for line in (s .. "\n"):gmatch("(.-)\n") do
		out[#out + 1] = line
	end
	if #out > 0 and out[#out] == "" then out[#out] = nil end
	return out
end

-- Find the unique 0-based start row of `needle` (list of lines) within `hay`
-- (buffer lines). Returns row, or nil with a reason ("missing"|"ambiguous").
function M.locate(hay, needle)
	local n = #needle
	if n == 0 then return nil, "missing" end
	local found, count = nil, 0
	for i = 1, #hay - n + 1 do
		local match = true
		for j = 1, n do
			if hay[i + j - 1] ~= needle[j] then
				match = false
				break
			end
		end
		if match then
			count = count + 1
			found = i - 1
			if count > 1 then return nil, "ambiguous" end
		end
	end
	if not found then return nil, "missing" end
	return found
end

-- Normalize a raw patch from the queue into internal form.
function M.normalize(raw)
	return {
		old_lines = split_lines(raw.old or ""),
		new_lines = split_lines(raw.new or ""),
		why = raw.why or "",
		key = (raw.old or "") .. "\0" .. (raw.new or ""),
	}
end

-- Current 0-based [start, end] rows of a patch in the buffer, or nil.
function M.range(buf, patch)
	local hay = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local row, reason = M.locate(hay, patch.old_lines)
	if not row then return nil, reason end
	return row, row + #patch.old_lines - 1
end

function M.apply(buf, patch)
	local sr = M.range(buf, patch)
	if not sr then return false end
	vim.api.nvim_buf_set_lines(buf, sr, sr + #patch.old_lines, false, patch.new_lines)
	return true
end

return M
