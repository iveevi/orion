-- Per-buffer state for the patcher job and the prev-save baseline.
-- (Proposed diffs live globally in wake.store, not here.)
local M = { buffers = {} }

function M.get(buf)
	local s = M.buffers[buf]
	if not s then
		s = { job = nil, runid = nil, prev = nil }
		M.buffers[buf] = s
	end
	return s
end

function M.drop(buf)
	M.buffers[buf] = nil
end

return M
