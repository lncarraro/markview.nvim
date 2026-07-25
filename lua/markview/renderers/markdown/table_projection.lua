local projection = {};

local dbg = require("markview.debug");
local utils = require("markview.utils");

local namespace = vim.api.nvim_create_namespace("markview/markdown/table-projection");

---@type table<integer, table<integer, { chunks: table[], display_col_start: integer }>>
local projected_rows = {};
---@type table<integer, integer>
local window_leftcols = {};

--- Removes {width} display cells from the start of a virtual text value.
---@param chunks table[]
---@param width integer
---@param display_col_start integer
---@return table[]
local function trim_chunks (chunks, width, display_col_start)
	if width <= 0 then
		return chunks;
	end

	local trimmed = {};
	local consumed = 0;

	for index, chunk in ipairs(chunks) do
		local text = chunk[1] or "";
		local chunk_width = vim.fn.strdisplaywidth(text, display_col_start + consumed);

		if consumed + chunk_width <= width then
			consumed = consumed + chunk_width;
		else
			local start = 0;
			local char_count = vim.fn.strchars(text, true);

			while start < char_count and consumed < width do
				local char = vim.fn.strcharpart(text, start, 1, true);
				consumed = consumed + vim.fn.strdisplaywidth(
					char,
					display_col_start + consumed
				);
				start = start + 1;
			end

			local remainder = string.rep(" ", math.max(0, consumed - width)) ..
				vim.fn.strcharpart(text, start, char_count - start, true);

			if remainder ~= "" then
				table.insert(trimmed, { remainder, chunk[2] });
			end

			for tail = index + 1, #chunks do
				table.insert(trimmed, chunks[tail]);
			end

			break;
		end
	end

	return trimmed;
end

vim.api.nvim_set_decoration_provider(namespace, {
	on_win = function (_, window, buffer)
		if not projected_rows[buffer] then
			return false;
		end

		local info = vim.fn.getwininfo(window)[1] or {};
		window_leftcols[window] = info.leftcol or 0;
	end,

	on_line = function (_, window, buffer, row)
		local projected = projected_rows[buffer] and projected_rows[buffer][row];

		if not projected then
			return;
		end

		local leftcol = window_leftcols[window] or 0;
		local hidden_width = math.max(0, leftcol - projected.display_col_start);
		local chunks = trim_chunks(
			projected.chunks,
			hidden_width,
			projected.display_col_start
		);

		if #chunks == 0 then
			return;
		end

		vim.api.nvim_buf_set_extmark(buffer, namespace, row, 0, {
			ephemeral = true,
			virt_text = chunks,
			virt_text_win_col = math.max(0, projected.display_col_start - leftcol),
			priority = 1000,
			hl_mode = "replace"
		});
	end
});

local function part (config, kind, index)
	local text = config.parts and config.parts[kind] and config.parts[kind][index] or "";
	local hl = config.hl and config.hl[kind] and config.hl[kind][index] or nil;

	return { text, utils.set_hl(hl) };
end

local function text_chunk (text)
	return { text or "" };
end

local function normalized_cell (text, strict)
	text = text or "";

	if strict ~= true then
		return text;
	end

	local leading = text:match("^%s*") or "";
	local trailing = text:match("%s*$") or "";
	local inner_start = #leading + 1;
	local inner_end = #text - #trailing;
	local inner = inner_start <= inner_end and text:sub(inner_start, inner_end) or "";

	return (leading ~= "" and " " or "") .. inner .. (trailing ~= "" and " " or "");
end

local function padded_cell (text, width, alignment, strict)
	text = normalized_cell(text, strict);
	local visible = vim.fn.strdisplaywidth(text);
	local remaining = math.max(0, width - visible);

	if alignment == "right" then
		return string.rep(" ", remaining) .. (text or "");
	elseif alignment == "center" then
		return string.rep(" ", math.ceil(remaining / 2)) ..
			(text or "") ..
			string.rep(" ", math.floor(remaining / 2));
	end

	return (text or "") .. string.rep(" ", remaining);
end

local function separator_cell (config, width, alignment)
	local border = config.parts and config.parts.separator and config.parts.separator[2] or "-";
	local border_hl = config.hl and config.hl.separator and config.hl.separator[2] or nil;
	local chunks = {};

	if alignment == "left" then
		table.insert(chunks, {
			config.parts.align_left or "",
			utils.set_hl(config.hl and config.hl.align_left or nil)
		});
		table.insert(chunks, {
			string.rep(border, math.max(0, width - 1)),
			utils.set_hl(border_hl)
		});
	elseif alignment == "right" then
		table.insert(chunks, {
			string.rep(border, math.max(0, width - 1)),
			utils.set_hl(border_hl)
		});
		table.insert(chunks, {
			config.parts.align_right or "",
			utils.set_hl(config.hl and config.hl.align_right or nil)
		});
	elseif alignment == "center" then
		local markers = config.parts.align_center or { "", "" };
		local marker_hls = config.hl and config.hl.align_center or {};

		table.insert(chunks, { markers[1] or "", utils.set_hl(marker_hls[1]) });
		table.insert(chunks, {
			string.rep(border, math.max(0, width - 2)),
			utils.set_hl(border_hl)
		});
		table.insert(chunks, { markers[2] or "", utils.set_hl(marker_hls[2]) });
	else
		table.insert(chunks, {
			string.rep(border, width),
			utils.set_hl(border_hl)
		});
	end

	return chunks;
end

local function row_chunks (config, kind, cells, widths, alignments, strict)
	local chunks = { part(config, kind, 1) };

	for column, width in ipairs(widths) do
		table.insert(chunks, text_chunk(padded_cell(
			cells[column] or "",
			width,
			alignments[column],
			strict
		)));

		table.insert(chunks, part(config, kind, column == #widths and 3 or 2));
	end

	return chunks;
end

local function separator_chunks (config, widths, alignments)
	local chunks = { part(config, "separator", 1) };

	for column, width in ipairs(widths) do
		vim.list_extend(chunks, separator_cell(config, width, alignments[column]));
		table.insert(chunks, part(config, "separator", column == #widths and 3 or 4));
	end

	return chunks;
end

local function border_chunks (config, kind, widths)
	local chunks = { part(config, kind, 1) };
	local fill = config.parts and config.parts[kind] and config.parts[kind][2] or "";
	local fill_hl = config.hl and config.hl[kind] and config.hl[kind][2] or nil;

	for column, width in ipairs(widths) do
		table.insert(chunks, {
			string.rep(fill, width),
			utils.set_hl(fill_hl)
		});
		table.insert(chunks, part(config, kind, column == #widths and 3 or 4));
	end

	return chunks;
end

local function project_source_row (buffer, namespace, table_row, source_row, col_start, kind, chunks)
	local line = vim.api.nvim_buf_get_lines(buffer, source_row, source_row + 1, false)[1] or "";
	local anchor = math.min(col_start, #line);
	local display_col_start = vim.fn.strdisplaywidth(string.sub(line, 1, anchor));
	local source_width = vim.fn.strdisplaywidth(
		string.sub(line, anchor + 1),
		display_col_start
	);
	local projected_width = utils.virt_len(chunks);
	local mask_width = math.max(0, source_width - projected_width);
	local overlay = vim.deepcopy(chunks);

	if mask_width > 0 then
		table.insert(overlay, { string.rep(" ", mask_width) });
	end

	projected_rows[buffer] = projected_rows[buffer] or {};
	projected_rows[buffer][source_row] = {
		chunks = overlay,
		display_col_start = display_col_start
	};

	dbg.log("table-projection", ("table_row=%d source_row=%d kind=%s mode=window-overlay anchor=%d display_col_start=%d source_bytes=%d source_width=%d projected_width=%d mask_width=%d"):format(
		table_row,
		source_row,
		kind,
		anchor,
		display_col_start,
		#line,
		source_width,
		projected_width,
		mask_width
	));
end

local function project_border (buffer, namespace, table_row, source_row, col_start, kind, chunks)
	if source_row < 0 or source_row >= vim.api.nvim_buf_line_count(buffer) then
		return;
	end

	local line = vim.api.nvim_buf_get_lines(buffer, source_row, source_row + 1, false)[1] or "";
	local projected = {};

	if col_start > 0 then
		table.insert(projected, { string.rep(" ", col_start) });
	end

	vim.list_extend(projected, chunks);

	local source_width = vim.fn.strdisplaywidth(line);
	local projected_width = utils.virt_len(projected);
	local mask_width = math.max(0, source_width - projected_width);

	if mask_width > 0 then
		table.insert(projected, { string.rep(" ", mask_width) });
	end

	projected_rows[buffer] = projected_rows[buffer] or {};
	projected_rows[buffer][source_row] = {
		chunks = projected,
		display_col_start = 0
	};

	dbg.log("table-projection", ("table_row=%d source_row=%d kind=%s mode=window-overlay anchor=0 source_bytes=%d source_width=%d projected_width=%d mask_width=%d"):format(
		table_row,
		source_row,
		kind,
		#line,
		source_width,
		projected_width,
		mask_width
	));
end

---@param buffer integer
---@param from integer?
---@param to integer?
projection.clear = function (buffer, from, to)
	if not projected_rows[buffer] then
		return;
	elseif from == nil or (from == 0 and (to == nil or to == -1)) then
		projected_rows[buffer] = nil;
		return;
	end

	for row, _ in pairs(projected_rows[buffer]) do
		if row >= from and (to == nil or to == -1 or row < to) then
			projected_rows[buffer][row] = nil;
		end
	end

	if vim.tbl_isempty(projected_rows[buffer]) then
		projected_rows[buffer] = nil;
	end
end

---@param buffer integer
---@param namespace integer
---@param item markview.parsed.markdown.tables
---@param config markview.config.markdown.tables
---@param rendered_texts { header: string[], rows: string[][] }
---@param col_widths integer[]
---@param strict boolean
projection.render = function (buffer, namespace, item, config, rendered_texts, col_widths, strict)
	local range = item.range;
	local alignments = item.alignments or {};

	if config.block_decorator == true and item.top_border == true then
		project_border(
			buffer,
			namespace,
			range.row_start,
			range.row_start - 1,
			range.col_start,
			"top",
			border_chunks(config, "top", col_widths)
		);
	end

	project_source_row(
		buffer,
		namespace,
		range.row_start,
		range.row_start,
		range.col_start,
		"header",
		row_chunks(config, "header", rendered_texts.header, col_widths, alignments, strict)
	);

	project_source_row(
		buffer,
		namespace,
		range.row_start,
		range.row_start + 1,
		range.col_start,
		"separator",
		separator_chunks(config, col_widths, alignments)
	);

	for row, cells in ipairs(rendered_texts.rows) do
		project_source_row(
			buffer,
			namespace,
			range.row_start,
			range.row_start + 1 + row,
			range.col_start,
			"row",
			row_chunks(config, "row", cells, col_widths, alignments, strict)
		);
	end

	if config.block_decorator == true and item.bottom_border == true then
		local bottom_kind = item.border_overlap == true and "overlap" or "bottom";

		project_border(
			buffer,
			namespace,
			range.row_start,
			range.row_end,
			range.col_start,
			bottom_kind,
			border_chunks(config, bottom_kind, col_widths)
		);
	end
end

return projection;
