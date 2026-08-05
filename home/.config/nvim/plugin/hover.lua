local namespace = vim.api.nvim_create_namespace('hover.code')
local group = vim.api.nvim_create_augroup('HoverAppearance', { clear = true })

local function resolved(name)
	return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function apply_highlights()
	local accent = resolved('Function').fg
	local muted = resolved('Comment').fg

	vim.api.nvim_set_hl(0, 'HoverBorder', { fg = accent, bg = 'NONE' })
	vim.api.nvim_set_hl(0, 'HoverBorderEdge', { fg = muted, bg = 'NONE' })
	vim.api.nvim_set_hl(0, 'HoverTitle', { fg = resolved('Normal').bg, bg = accent, bold = true })
	vim.api.nvim_set_hl(0, 'HoverTitleCap', { fg = accent, bg = 'NONE' })
	vim.api.nvim_set_hl(0, 'HoverFooter', { fg = muted, bg = 'NONE', italic = true })
	vim.api.nvim_set_hl(0, 'HoverDivider', { fg = muted, bg = 'NONE' })
end

vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = apply_highlights })

apply_highlights()

local border = {
	{ '╭', 'HoverBorder' },
	{ '─', 'HoverBorderEdge' },
	{ '╮', 'HoverBorder' },
	{ '│', 'HoverBorderEdge' },
	{ '╯', 'HoverBorder' },
	{ '─', 'HoverBorderEdge' },
	{ '╰', 'HoverBorder' },
	{ '│', 'HoverBorderEdge' },
}

local function buffer_language(bufnr)
	local filetype = vim.bo[bufnr].filetype
	return vim.treesitter.language.get_lang(filetype) or filetype
end

local function title_chunks(bufnr)
	local names = {}
	for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/hover' }) do
		table.insert(names, client.name)
	end

	if #names == 0 then
		return nil
	end

	local icon = require('nvim-web-devicons').get_icon_by_filetype(vim.bo[bufnr].filetype, { default = true })

	return {
		{ '', 'HoverTitleCap' },
		{ (' %s %s '):format(icon, table.concat(names, ' ')), 'HoverTitle' },
		{ '', 'HoverTitleCap' },
	}
end

local function split_contents(contents)
	local markdown = vim.lsp.util.convert_input_to_markdown_lines(contents)
	local code = {}
	local prose = {}
	local inside = false

	for _, line in ipairs(vim.split(table.concat(markdown, '\n'), '\n')) do
		if line:match('^```') then
			inside = not inside
		elseif inside then
			table.insert(code, line)
		else
			local cleaned = line:gsub('&nbsp;', ' '):gsub('%s+$', '')
			if cleaned ~= '' and not cleaned:match('^[-=_]+$') then
				table.insert(prose, cleaned)
			end
		end
	end

	return code, prose
end

local function take_location(prose)
	for index = #prose, 1, -1 do
		local file, line = prose[index]:match('^Defined in (.+)%((%d+)%)$')
		if file then
			table.remove(prose, index)
			return (' %s:%s '):format(vim.fn.fnamemodify(file, ':t'), line)
		end
	end
end

local function highlight_code(bufnr, code, language)
	if #code == 0 then
		return
	end

	local source = table.concat(code, '\n')
	local ok, parser = pcall(vim.treesitter.get_string_parser, source, language)
	if not ok then
		return
	end

	local query = vim.treesitter.query.get(language, 'highlights')
	if not query then
		return
	end

	for id, node in query:iter_captures(parser:parse()[1]:root(), source) do
		local start_row, start_col, end_row, end_col = node:range()
		pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, start_row, start_col, {
			end_row = end_row,
			end_col = end_col,
			hl_group = '@' .. query.captures[id],
			priority = 120,
		})
	end
end

local function show(bufnr, contents)
	local code, prose = split_contents(contents)
	if #code == 0 and #prose == 0 then
		return
	end

	local location = take_location(prose)

	local width = 20
	for _, line in ipairs(vim.list_extend(vim.list_slice(code, 1, #code), prose)) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(width, math.floor(vim.o.columns * 0.9))

	local divided = #code > 0 and #prose > 0
	local lines = vim.list_slice(code, 1, #code)
	if divided then
		table.insert(lines, string.rep('─', width))
	end
	vim.list_extend(lines, prose)

	local float_buf, float_win = vim.lsp.util.open_floating_preview(lines, '', {
		border = border,
		title = title_chunks(bufnr),
		title_pos = 'left',
		width = width,
		max_height = math.floor(vim.o.lines * 0.6),
		focus_id = 'textDocument/hover',
	})

	highlight_code(float_buf, code, buffer_language(bufnr))

	if divided then
		vim.api.nvim_buf_set_extmark(float_buf, namespace, #code, 0, {
			end_col = #lines[#code + 1],
			hl_group = 'HoverDivider',
		})
	end

	if location then
		local config = vim.api.nvim_win_get_config(float_win)
		config.footer = { { location, 'HoverFooter' } }
		config.footer_pos = 'right'
		vim.api.nvim_win_set_config(float_win, config)
	end
end

local function lsp_hover()
	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	local params = function(client)
		return vim.lsp.util.make_position_params(win, client.offset_encoding)
	end

	vim.lsp.buf_request_all(bufnr, 'textDocument/hover', params, function(results)
		for _, response in pairs(results) do
			if response.result and response.result.contents then
				show(bufnr, response.result.contents)
				return
			end
		end
	end)
end

local function hover()
	if #vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 }) > 0 then
		vim.diagnostic.open_float {
			border = border,
			title = ' diagnostics ',
			title_pos = 'left',
			header = '',
			max_width = math.floor(vim.o.columns * 0.9),
			focusable = true,
		}
		return
	end

	lsp_hover()
end

vim.keymap.set('n', 'hh', hover, { noremap = true, silent = true })
