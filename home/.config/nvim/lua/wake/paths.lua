-- Resolve the git toplevel and the centralized wake stream dir for a file.
-- Mirrors the shell hooks: key = first 16 hex of sha1(toplevel-path).
local M = { _root = {}, _key = {} }

local function run(cmd, opts)
	local res = vim.system(cmd, opts or {}):wait()
	if res.code ~= 0 then return nil end
	return (res.stdout or ""):gsub("%s+$", "")
end

function M.root(file)
	local dir = vim.fs.dirname(file)
	if M._root[dir] ~= nil then return M._root[dir] or nil end
	local top = run({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
	M._root[dir] = top or false
	return top
end

function M.key(root)
	if M._key[root] then return M._key[root] end
	local res = vim.system({ "sha1sum" }, { stdin = root }):wait()
	local k = (res.stdout or ""):sub(1, 16)
	M._key[root] = k
	return k
end

-- Returns { root, key, stream, inbox } or nil if the file is not in a git repo.
function M.resolve(file)
	local root = M.root(file)
	if not root then return nil end
	local key = M.key(root)
	local stream = vim.fs.normalize(vim.env.HOME .. "/.claude/wake/" .. key .. "/stream")
	return {
		root = root,
		key = key,
		stream = stream,
		inbox = stream .. "/inbox",
	}
end

return M
