-- Global registry of proposed diffs across all files in the repo, plus the
-- aggregate processing state that drives the statusline and panel.
local M = {
	diffs = {}, -- { { file_abs, file_rel, old_lines, new_lines, why, key } }
	seen = {}, -- key -> true (dedupe)
	active = 0, -- number of in-flight patcher jobs
	frame = 1, -- spinner frame
	last_error = nil,
	last_stdout = nil,
}

function M.add(entries)
	local added = 0
	for _, d in ipairs(entries) do
		if not M.seen[d.key] then
			M.seen[d.key] = true
			M.diffs[#M.diffs + 1] = d
			added = added + 1
		end
	end
	return added
end

function M.for_file(abs)
	local out = {}
	for _, d in ipairs(M.diffs) do
		if d.file_abs == abs then out[#out + 1] = d end
	end
	return out
end

function M.count() return #M.diffs end

function M.clear()
	M.diffs = {}
	M.seen = {}
end

function M.status()
	if M.active > 0 then return "processing" end
	if #M.diffs > 0 then return "ready" end
	return "idle"
end

return M
