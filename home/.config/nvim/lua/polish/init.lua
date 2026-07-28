local M = {}

local VOICE = [[
Match the register of the surrounding document. Do not raise or lower its formality,
vocabulary, or sentence complexity; a long clause-heavy sentence should stay long.
Keep the author's technical vocabulary exactly as written, including terms of art
that resemble filler in ordinary prose.

Avoid the following, which read as machine-written:
- rhetorical antithesis used for cadence: "not X, but Y", "X isn't just Y, it's Z",
  "it is less about X than about Y"
- three-item lists assembled for rhythm rather than because there are three things
- trailing participial clauses: "..., making it", "..., allowing you to", "..., ensuring that"
- throat-clearing: "it is worth noting", "importantly", "notably", "in essence",
  "at its core", "fundamentally"
- inflated register: delve, realm, landscape, tapestry, testament, pivotal, intricate
- a closing sentence that restates what was just said

Punctuation is plain ASCII: straight quotes and apostrophes, never typographic.
Do not introduce em dashes or en dashes. Semicolons and colons are fine where the
grammar calls for them.]]

local POLISH_SYSTEM = [[
Polish the user's text: fix grammar, tighten wording, improve clarity. Preserve the
original meaning, voice, and formatting including markdown, code, and indentation.
Output ONLY the revised text, with no preamble, explanation, or surrounding quotation marks.]]

local POLISH_MARKUP = [[
Copy all markup, commands, environments, math, identifiers, labels, and citation keys
through byte-for-byte. Revise only the prose between them.]]

local REWRITE_SYSTEM = [[
Rewrite the user's text as complete, well-formed prose. Finish incomplete sentences,
resolve fragments and notes into full statements, and develop underdeveloped points
into their intended form. Restructure freely for flow and argument, but stay faithful
to the author's intent, voice, and every technical detail. Never invent facts, numbers,
or citations. Preserve formatting including markdown, code, and indentation.
Output ONLY the rewritten text, with no preamble, explanation, or surrounding quotation marks.]]

local REWRITE_MARKUP = [[
Revise and complete the typesetting as well as the prose: finish unclosed environments,
fill in half-written math, and promote inline expressions to display form where that
reads better. Keep identifiers, labels, and citation keys exactly as written, and never
invent a citation key or reference that is not already present.]]

local defaults = {
	url = "http://localhost:11434/api/chat",
	model = "qwen3.6:35b",
	num_ctx = 32768,
	max_context = 48000,
	context_lines = 80,
	voice = VOICE,
	modes = {
		{ temperature = 0.3, system = POLISH_SYSTEM, markup = POLISH_MARKUP },
		{ temperature = 0.35, system = REWRITE_SYSTEM, markup = REWRITE_MARKUP },
	},
}

local languages = {
	tex = "LaTeX",
	plaintex = "LaTeX",
	bib = "BibTeX",
	markdown = "Markdown",
	typst = "Typst",
	rst = "reStructuredText",
	org = "Org-mode",
	html = "HTML",
	quarto = "Quarto Markdown",
}

local config = vim.deepcopy(defaults)
local ns = vim.api.nvim_create_namespace("polish")
local active = nil

local function selection_range()
	local mode = vim.fn.mode()
	if not mode:match("^[vV\22]") then
		return nil
	end
	local regions = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
	if #regions == 0 then
		return nil
	end
	local first, last = regions[1][1], regions[#regions][2]
	local erow = last[2] - 1
	local line = vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or ""
	return first[2] - 1, first[3] - 1, erow, math.min(last[3], #line)
end

local function advance(row, col, lines)
	if #lines == 1 then
		return row, col + #lines[1]
	end
	return row + #lines - 1, #lines[#lines]
end

local function apply(state, chunk)
	if not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local lines = vim.split(chunk, "\n", { plain = true })
	if state.started then
		pcall(vim.cmd.undojoin)
		vim.api.nvim_buf_set_text(state.buf, state.row, state.col, state.row, state.col, lines)
	else
		vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
		vim.api.nvim_buf_set_text(state.buf, state.srow, state.scol, state.erow, state.ecol, lines)
		state.started = true
		state.row, state.col = state.srow, state.scol
	end
	state.row, state.col = advance(state.row, state.col, lines)
end

local function consume(state, data)
	state.pending = state.pending .. data
	while true do
		local nl = state.pending:find("\n", 1, true)
		if not nl then
			return
		end
		local line = state.pending:sub(1, nl - 1)
		state.pending = state.pending:sub(nl + 1)
		local ok, obj = pcall(vim.json.decode, line)
		if ok and type(obj) == "table" and obj.message then
			local chunk = obj.message.content
			if type(chunk) == "string" and chunk ~= "" then
				if not state.started then
					chunk = chunk:gsub("^%s+", "")
				end
				if chunk ~= "" then
					apply(state, chunk)
				end
			end
		end
	end
end

-- Repair LaTeX math the model emitted into a Typst buffer. typstfix compiles
-- each math span and only rewrites the ones that fail as Typst and succeed as
-- converted LaTeX, so valid Typst is never touched.
local function repair_math(state)
	if not state.started or vim.bo[state.buf].filetype ~= "typst" then
		return
	end
	local erow, ecol = state.row, state.col
	local text = table.concat(vim.api.nvim_buf_get_text(state.buf, state.srow, state.scol, erow, ecol, {}), "\n")
	if not text:find("$", 1, true) then
		return
	end
	vim.system({ "typstfix", "-q" }, { stdin = text }, function(res)
		if res.code ~= 0 or not res.stdout or res.stdout == "" or res.stdout == text then
			return
		end
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(state.buf) then
				return
			end
			pcall(vim.cmd.undojoin)
			local lines = vim.split(res.stdout, "\n", { plain = true })
			vim.api.nvim_buf_set_text(state.buf, state.srow, state.scol, erow, ecol, lines)
		end)
	end)
end

local function request(body, stdout, on_exit)
	return vim.system({
		"curl",
		"-sN",
		"--no-buffer",
		config.url,
		"-H",
		"Content-Type: application/json",
		"--data-binary",
		"@-",
	}, { stdin = body, stdout = stdout }, on_exit)
end

-- Voice exemplars, read once. Static, so the server's prefix cache absorbs them.
local style_cache = nil

local function style()
	if style_cache == nil then
		local path = vim.fn.stdpath("config") .. "/lua/polish/style.md"
		local ok, lines = pcall(vim.fn.readfile, path)
		style_cache = ok and #lines > 0 and ("\n\n" .. table.concat(lines, "\n")) or false
	end
	return style_cache or ""
end

local function language(buf, mode)
	local ft = buf and vim.bo[buf].filetype or ""
	local name = languages[ft] or ft
	if name == "" then
		return ""
	end
	return " The source language is " .. name .. ". " .. mode.markup
end

-- The whole document is sent as context with the selection marked in place, then
-- the selection is repeated so the model has an unambiguous edit target. Beyond
-- max_context bytes the document is trimmed to a window of lines around it.
local function build_prompt(buf, srow, scol, erow, ecol, selection)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local last_row = math.max(#lines - 1, 0)
	local last_col = #(lines[#lines] or "")

	local total = 0
	for _, l in ipairs(lines) do
		total = total + #l + 1
	end

	local from_row, to_row = 0, last_row
	local from_col, to_col = 0, last_col
	if total > config.max_context then
		local pad = config.context_lines
		from_row = math.max(srow - pad, 0)
		to_row = math.min(erow + pad, last_row)
		from_col = 0
		to_col = #(lines[to_row + 1] or "")
	end

	local before = table.concat(vim.api.nvim_buf_get_text(buf, from_row, from_col, srow, scol, {}), "\n")
	local after = table.concat(vim.api.nvim_buf_get_text(buf, erow, ecol, to_row, to_col, {}), "\n")

	return table.concat({
		"<document>",
		before .. "<<<EXCERPT>>>" .. selection .. "<<<END EXCERPT>>>" .. after,
		"</document>",
		"",
		"The document above is for context only. Revise ONLY the text between the",
		"<<<EXCERPT>>> markers, reproduced below. Use the document to resolve pronouns,",
		"terminology, and register, but do not repeat, summarize, or edit any of it.",
		"Output the revised excerpt alone, with no markers and no surrounding text.",
		"",
		"<excerpt>",
		selection,
		"</excerpt>",
	}, "\n")
end

local function encode(text, stream, mode, buf)
	return vim.json.encode({
		model = config.model,
		stream = stream,
		think = false,
		keep_alive = -1,
		options = { temperature = mode.temperature, num_ctx = config.num_ctx },
		messages = {
			{ role = "system", content = mode.system .. config.voice .. language(buf, mode) .. style() },
			{ role = "user", content = text },
		},
	})
end

function M.polish(index)
	local mode = config.modes[index or 1]
	if active or not mode then
		return
	end
	local srow, scol, erow, ecol = selection_range()
	if not srow then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local selection = table.concat(vim.api.nvim_buf_get_text(buf, srow, scol, erow, ecol, {}), "\n")
	if selection:match("^%s*$") then
		return
	end
	local text = build_prompt(buf, srow, scol, erow, ecol, selection)

	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	vim.api.nvim_buf_set_extmark(buf, ns, srow, scol, {
		end_row = erow,
		end_col = ecol,
		hl_group = "Visual",
	})

	local state = {
		buf = buf,
		srow = srow,
		scol = scol,
		erow = erow,
		ecol = ecol,
		pending = "",
		started = false,
	}

	active = request(encode(text, true, mode, buf), function(err, data)
		if err or not data then
			return
		end
		vim.schedule(function()
			consume(state, data)
		end)
	end, function(res)
		active = nil
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			end
			if res.code ~= 0 then
				vim.notify("polish: request failed (" .. res.code .. ")", vim.log.levels.ERROR)
				return
			end
			repair_math(state)
		end)
	end)
end

function M.warm()
	request(encode("hi", false, config.modes[1]), nil, nil)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
