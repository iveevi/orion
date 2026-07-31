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

local CUSTOM_SYSTEM = [[
Apply the user's instruction to the excerpt. The instruction takes precedence over
any default editing behaviour, but never over factual accuracy: do not invent facts,
numbers, citations, or references. Preserve formatting including markdown, code, and
indentation unless the instruction says otherwise.
Output ONLY the revised excerpt, with no preamble, explanation, or surrounding quotation marks.]]

local CUSTOM_MARKUP = [[
Keep markup, commands, environments, identifiers, labels, and citation keys intact
unless the instruction explicitly asks you to change them.]]

local AGENT_SYSTEM = [[
You are invoked from inside the user's editor. They highlighted a region of a
file and typed an instruction about it. The file, its line range, and the excerpt
are given in the message.

Carry out the instruction by editing files directly with your tools. You are not
confined to the highlighted region: change whatever the instruction requires,
elsewhere in the file or in related files. The editor reloads from disk when you
finish, so every change must actually be written, never described.

Prefer targeted edits over rewriting whole files; the user's only recourse is undo.

If the instruction is a question rather than an edit request, answer it in your
final message and change nothing. Your final message is surfaced as a short
notification in the editor, so keep it to a few lines and do not recount edits
you already made.]]

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
		{ model = "opus", system = CUSTOM_SYSTEM, markup = CUSTOM_MARKUP, label = "instruction" },
		{
			model = "opus",
			system = AGENT_SYSTEM,
			bare = true,
			agent = true,
			effort = "medium",
			label = "prompt",
		},
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
local spin_ns = vim.api.nvim_create_namespace("polish_spinner")
local ask_ns = vim.api.nvim_create_namespace("polish_ask")
local active = nil

-- Mixes `top` over `bottom` at the given alpha, both packed 0xRRGGBB.
local function blend(top, bottom, alpha)
	local out = 0
	for _, shift in ipairs({ 16, 8, 0 }) do
		local a = math.floor(top / 2 ^ shift) % 256
		local b = math.floor(bottom / 2 ^ shift) % 256
		out = out + math.floor(a * alpha + b * (1 - alpha) + 0.5) * 2 ^ shift
	end
	return math.floor(out)
end

-- Tinted with the same accent the popup's border and title use, so the pending
-- region reads as part of the popup rather than as another Visual selection.
local function pending_highlight()
	local accent = vim.api.nvim_get_hl(0, { name = "Question", link = false }).fg
	local base = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
	if not accent or not base then
		return { link = "Search", default = true }
	end
	return { bg = string.format("#%06x", blend(accent, base, 0.25)), default = true }
end

-- Pulls unselected text most of the way toward the background.
local function dim_highlight()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	if not normal.fg or not normal.bg then
		return { link = "Comment", default = true }
	end
	return { fg = string.format("#%06x", blend(normal.fg, normal.bg, 0.3)), default = true }
end

-- Links are wiped by :colorscheme, so these are re-applied on every open rather
-- than once at load. `default` keeps any explicit user override intact.
local function setup_highlights()
	local hl = vim.api.nvim_set_hl
	hl(0, "PolishPending", pending_highlight())
	hl(0, "PolishDim", dim_highlight())
	hl(0, "PolishFloat", { link = "NormalFloat", default = true })
	hl(0, "PolishBorder", { link = "Comment", default = true })
	hl(0, "PolishIcon", { link = "Question", default = true })
	hl(0, "PolishTitle", { link = "Question", default = true })
	hl(0, "PolishKey", { link = "Special", default = true })
	hl(0, "PolishHint", { link = "Comment", default = true })
	hl(0, "PolishPrompt", { link = "Question", default = true })
	hl(0, "PolishSpinner", { link = "Question", default = true })
end

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- Lives in its own namespace: the selection highlight is cleared as soon as the
-- first chunk lands, but the spinner must survive until the request finishes.
-- A virtual line above the selection rather than virtual text on a real one, so
-- it starts at column zero and never overlays anything.
local function start_spinner(state, label)
	setup_highlights()
	local frame = 0
	local timer = vim.uv.new_timer()
	state.spinner = timer
	timer:start(
		0,
		80,
		vim.schedule_wrap(function()
			if not vim.api.nvim_buf_is_valid(state.buf) then
				return
			end
			frame = frame % #SPINNER + 1
			state.spinner_mark = vim.api.nvim_buf_set_extmark(state.buf, spin_ns, state.srow, 0, {
				id = state.spinner_mark,
				virt_lines = { { { SPINNER[frame] .. " " .. (state.label or label), "PolishSpinner" } } },
				virt_lines_above = true,
			})
		end)
	)
end

local function stop_spinner(state)
	if state.spinner then
		state.spinner:stop()
		state.spinner:close()
		state.spinner = nil
	end
	pcall(vim.api.nvim_buf_clear_namespace, state.buf, spin_ns, 0, -1)
end

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
		local chunk = state.delta(line)
		if type(chunk) == "string" and chunk ~= "" then
			if not state.started then
				chunk = chunk:gsub("^[\n\r]+", "")
			end
			if chunk ~= "" then
				apply(state, chunk)
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

local function ollama_delta(line)
	local ok, obj = pcall(vim.json.decode, line)
	if not ok or type(obj) ~= "table" or not obj.message then
		return nil
	end
	return obj.message.content
end

-- claude -p emits newline-delimited JSON; text arrives as content_block_delta
-- events, interleaved with thinking_delta events we ignore.
local function claude_delta(line)
	local ok, obj = pcall(vim.json.decode, line)
	if not ok or type(obj) ~= "table" or obj.type ~= "stream_event" then
		return nil
	end
	local event = obj.event
	if not event or event.type ~= "content_block_delta" then
		return nil
	end
	local delta = event.delta
	if not delta or delta.type ~= "text_delta" then
		return nil
	end
	return delta.text
end

-- The CLI otherwise inherits the user's CLAUDE.md, hooks, and skills, which
-- would shape prose output; --system-prompt replaces them wholesale. Agent mode
-- appends instead, since replacing it would also drop the CLI's tool guidance.
local function claude_run(mode, system, user, stdout, on_exit)
	local argv = {
		"claude",
		"-p",
		"--model",
		mode.model,
		mode.agent and "--append-system-prompt" or "--system-prompt",
		system,
		"--effort",
		mode.effort or "low",
		"--no-session-persistence",
		"--output-format",
		"stream-json",
		"--verbose",
	}
	if mode.agent then
		vim.list_extend(argv, { "--permission-mode", "auto" })
	else
		vim.list_extend(argv, { "--exclude-dynamic-system-prompt-sections", "--include-partial-messages" })
	end
	return vim.system(argv, { stdin = user, stdout = stdout, cwd = vim.uv.cwd() }, on_exit)
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

local function system_prompt(mode, buf, instruction)
	local head = mode.system
	if instruction then
		head = head .. "\n\nThe user's instruction for this excerpt:\n" .. instruction
	end
	if mode.bare then
		return head
	end
	return head .. config.voice .. language(buf, mode) .. style()
end

-- Bare modes are not prose editing, so they get the excerpt plus its provenance
-- rather than the whole document and the voice apparatus.
local function build_excerpt(buf, srow, erow, selection)
	local name = vim.api.nvim_buf_get_name(buf)
	name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[unnamed buffer]"
	local ft = vim.bo[buf].filetype
	return table.concat({
		"File: " .. name .. (ft ~= "" and (" (" .. ft .. ")") or ""),
		string.format("Lines %d-%d", srow + 1, erow + 1),
		"",
		"<excerpt>",
		selection,
		"</excerpt>",
	}, "\n")
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

local function encode(text, stream, mode, buf, instruction)
	return vim.json.encode({
		model = config.model,
		stream = stream,
		think = false,
		keep_alive = -1,
		options = { temperature = mode.temperature, num_ctx = config.num_ctx },
		messages = {
			{ role = "system", content = system_prompt(mode, buf, instruction) },
			{ role = "user", content = text },
		},
	})
end

-- Screen row of a buffer line, relative to the top of its window. Returns nil
-- when the line is scrolled out of view.
local function window_row(win, lnum)
	local pos = vim.fn.screenpos(win, lnum + 1, 1)
	if pos.row == 0 then
		return nil
	end
	return pos.row - 1 - vim.api.nvim_win_get_position(win)[1]
end

-- Single-line input, horizontally centred in the window and floating above the
-- selection with one blank screen line between the bottom border and it.
local function ask(anchor_win, range, label, on_submit)
	setup_highlights()

	local srow, scol, erow, ecol = range[1], range[2], range[3], range[4]
	local anchor_buf = vim.api.nvim_win_get_buf(anchor_win)
	vim.api.nvim_buf_set_extmark(anchor_buf, ask_ns, srow, scol, {
		end_row = erow,
		end_col = ecol,
		hl_group = "PolishPending",
	})

	-- Everything outside the selection is dimmed as two spans that stop at its
	-- edges. A priority above treesitter's 100 is needed to override syntax fg.
	local last = vim.api.nvim_buf_line_count(anchor_buf) - 1
	local tail = #(vim.api.nvim_buf_get_lines(anchor_buf, last, last + 1, true)[1] or "")
	local function dim(r1, c1, r2, c2)
		if r1 < r2 or (r1 == r2 and c1 < c2) then
			vim.api.nvim_buf_set_extmark(anchor_buf, ask_ns, r1, c1, {
				end_row = r2,
				end_col = c2,
				hl_group = "PolishDim",
				priority = 200,
			})
		end
	end
	dim(0, 0, srow, scol)
	dim(erow, ecol, last, tail)

	local buf = vim.api.nvim_create_buf(false, true)
	-- blink.cmp gates on this buffer variable; without it the input pops a
	-- completion menu over the very selection the popup is asking about.
	vim.b[buf].completion = false

	local wwidth = vim.api.nvim_win_get_width(anchor_win)
	local wheight = vim.api.nvim_win_get_height(anchor_win)

	local width = math.max(math.min(76, wwidth - 6), 24)
	local frame = 3 -- one text row plus the two border rows

	local top = window_row(anchor_win, srow)
	local row
	if not top then
		row = math.floor((wheight - frame) / 2)
	elseif top >= frame + 1 then
		row = top - frame - 1
	else
		-- No room above: drop below the selection instead of clipping it.
		row = (window_row(anchor_win, erow) or top) + 1
	end
	row = math.max(math.min(row, wheight - frame), 0)

	local opts = {
		relative = "win",
		win = anchor_win,
		row = row,
		col = math.floor((wwidth - width - 2) / 2),
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = { { " ✦ ", "PolishIcon" }, { label, "PolishTitle" }, { " ", "PolishTitle" } },
		title_pos = "center",
		footer = {
			{ " ⏎ ", "PolishKey" },
			{ "send", "PolishHint" },
			{ "  esc ", "PolishKey" },
			{ "cancel ", "PolishHint" },
		},
		footer_pos = "right",
	}
	local ok, win = pcall(vim.api.nvim_open_win, buf, true, opts)
	if not ok then
		opts.relative = "editor"
		opts.win = nil
		opts.row = math.floor((vim.o.lines - frame) / 2)
		opts.col = math.floor((vim.o.columns - width - 2) / 2)
		win = vim.api.nvim_open_win(buf, true, opts)
	end
	vim.wo[win].winhighlight =
		"Normal:PolishFloat,FloatBorder:PolishBorder,FloatTitle:PolishTitle,FloatFooter:PolishHint"
	vim.wo[win].winblend = 0
	vim.wo[win].wrap = false
	vim.wo[win].sidescrolloff = 4

	-- Shell-style prompt glyph. Inline virtual text keeps it out of the buffer
	-- text, so it never reaches the model; left gravity pins it ahead of input.
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		virt_text = { { "❯ ", "PolishPrompt" } },
		virt_text_pos = "inline",
		right_gravity = false,
	})

	-- stopinsert is essential: the float is entered with startinsert, and without
	-- this the caller's window inherits insert mode once the float closes.
	local function close()
		vim.cmd.stopinsert()
		pcall(vim.api.nvim_buf_clear_namespace, anchor_buf, ask_ns, 0, -1)
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	local function submit()
		local input = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
		close()
		if input:match("%S") then
			on_submit(input)
		end
	end

	vim.keymap.set({ "n", "i" }, "<CR>", submit, { buffer = buf, nowait = true })
	vim.keymap.set({ "n", "i" }, "<Esc>", close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
	vim.schedule(function()
		vim.cmd.startinsert()
	end)
end

-- ---------------------------------------------------------------------------
-- Agent
-- ---------------------------------------------------------------------------

local function truncate(text, limit)
	text = text:gsub("%s+", " ")
	if vim.fn.strdisplaywidth(text) <= limit then
		return text
	end
	return vim.fn.strcharpart(text, 0, limit - 1) .. "…"
end

-- The argument worth showing differs per tool; these cover the ones that appear.
local function tool_detail(input)
	if type(input) ~= "table" then
		return nil
	end
	local path = input.file_path or input.notebook_path or input.path
	if path then
		return vim.fn.fnamemodify(path, ":t")
	end
	return input.command or input.pattern or input.url or input.description
end

-- Whole messages rather than token deltas: tool calls name the spinner, and the
-- terminal result message carries the reply to surface when the run ends.
local function agent_event(state, line)
	local ok, obj = pcall(vim.json.decode, line)
	if not ok or type(obj) ~= "table" then
		return
	end
	if obj.type == "assistant" and type(obj.message) == "table" then
		for _, block in ipairs(obj.message.content or {}) do
			if block.type == "tool_use" then
				local detail = tool_detail(block.input)
				state.label = block.name .. (detail and (" " .. truncate(detail, 24)) or "")
			end
		end
	elseif obj.type == "result" then
		state.reply = type(obj.result) == "string" and obj.result or nil
		state.label = "done"
	end
end

local function agent_consume(state, data)
	state.pending = state.pending .. data
	while true do
		local nl = state.pending:find("\n", 1, true)
		if not nl then
			return
		end
		agent_event(state, state.pending:sub(1, nl - 1))
		state.pending = state.pending:sub(nl + 1)
	end
end

-- The agent wrote to disk, so buffers have to be re-read. checktime is silent
-- here because the buffer was saved before the run and is therefore unmodified;
-- undo history survives the reload as long as the file fits 'undoreload'.
local function finish_agent(state)
	vim.cmd("silent! checktime")
	if state.reply and state.reply:match("%S") then
		vim.notify(vim.trim(state.reply))
	end
end

function M.polish(index, instruction, range)
	local mode = config.modes[index or 1]
	if active or not mode then
		return
	end
	local srow, scol, erow, ecol
	if range then
		srow, scol, erow, ecol = range[1], range[2], range[3], range[4]
	else
		srow, scol, erow, ecol = selection_range()
	end
	if not srow then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local selection = table.concat(vim.api.nvim_buf_get_text(buf, srow, scol, erow, ecol, {}), "\n")
	if selection:match("^%s*$") then
		return
	end
	local text = mode.bare and build_excerpt(buf, srow, erow, selection)
		or build_prompt(buf, srow, scol, erow, ecol, selection)

	-- The agent reads the file from disk, so unsaved edits have to land first.
	if mode.agent then
		if vim.api.nvim_buf_get_name(buf) == "" then
			vim.notify("polish: buffer is not backed by a file", vim.log.levels.ERROR)
			return
		end
		if vim.bo[buf].modified then
			local written = pcall(vim.api.nvim_buf_call, buf, function()
				vim.cmd("silent write")
			end)
			if not written then
				vim.notify("polish: could not write buffer", vim.log.levels.ERROR)
				return
			end
		end
		text = text .. "\n\nInstruction: " .. (instruction or "")
	end

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
		delta = mode.model and claude_delta or ollama_delta,
	}

	start_spinner(state, mode.model or config.model)

	local function on_stdout(err, data)
		if err or not data then
			return
		end
		vim.schedule(function()
			if mode.agent then
				agent_consume(state, data)
			else
				consume(state, data)
			end
		end)
	end

	local function on_finish(res)
		active = nil
		vim.schedule(function()
			stop_spinner(state)
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			end
			if res.code ~= 0 then
				vim.notify("polish: request failed (" .. res.code .. ")", vim.log.levels.ERROR)
				return
			end
			if mode.agent then
				finish_agent(state)
			else
				repair_math(state)
			end
		end)
	end

	if mode.model then
		local system = system_prompt(mode, buf, not mode.agent and instruction or nil)
		active = claude_run(mode, system, text, on_stdout, on_finish)
	else
		active = request(encode(text, true, mode, buf, instruction), on_stdout, on_finish)
	end
end

-- The input window steals the visual selection, and :normal! gv would restore the
-- mode only for the duration of that command, so the range is captured up front
-- and handed to polish directly.
function M.ask_polish(index)
	local srow, scol, erow, ecol = selection_range()
	if active or not srow then
		return
	end
	local win = vim.api.nvim_get_current_win()
	local range = { srow, scol, erow, ecol }
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	ask(win, range, config.modes[index].label or "prompt", function(instruction)
		if not vim.api.nvim_win_is_valid(win) then
			return
		end
		vim.api.nvim_set_current_win(win)
		M.polish(index, instruction, range)
	end)
end

function M.warm()
	request(encode("hi", false, config.modes[1]), nil, nil)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
