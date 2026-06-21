local table_overflow = {};

local dbg = require("markview.debug");

local function window_is_valid (window)
	return type(window) == "number" and vim.api.nvim_win_is_valid(window);
end

--- Enables lossless horizontal table rendering in one window.
---
--- The original `wrap` value is cached before the window is changed. Rendering
--- restores the cache before recalculating overflow, and preview lifecycle hooks
--- restore it when rendering is hidden, cleared, disabled, or detached.
---@param buffer integer
---@param window integer
---@return boolean applied
table_overflow.enable_horizontal = function (buffer, window)
	if not window_is_valid(window) then
		return false;
	elseif
		vim.w[window].__mkv_table_overflow_active == true and
		vim.w[window].__mkv_table_overflow_buffer ~= buffer
	then
		table_overflow.restore_window(window);
	end

	if vim.w[window].__mkv_table_overflow_active ~= true then
		vim.w[window].__mkv_table_overflow_wrap = vim.wo[window].wrap;
		vim.w[window].__mkv_table_overflow_buffer = buffer;
		vim.w[window].__mkv_table_overflow_active = true;
	end

	vim.w[window].__mkv_table_overflow_updating = true;
	local updated = pcall(vim.api.nvim_win_call, window, function ()
		vim.wo.wrap = false;
	end);
	vim.w[window].__mkv_table_overflow_updating = nil;

	if not updated then
		table_overflow.restore_window(window);
		return false;
	end

	dbg.log("table-overflow", ("buffer=%d window=%d mode=horizontal cached_wrap=%s current_wrap=%s"):format(
		buffer,
		window,
		tostring(vim.w[window].__mkv_table_overflow_wrap),
		tostring(vim.wo[window].wrap)
	));

	return true;
end

--- Restores the window-local `wrap` value cached by horizontal table mode.
---@param window integer
table_overflow.restore_window = function (window)
	if not window_is_valid(window) then
		return;
	elseif vim.w[window].__mkv_table_overflow_active ~= true then
		return;
	end

	local cached_wrap = vim.w[window].__mkv_table_overflow_wrap;

	if type(cached_wrap) == "boolean" then
		vim.w[window].__mkv_table_overflow_updating = true;
		pcall(vim.api.nvim_win_call, window, function ()
			vim.wo.wrap = cached_wrap;
		end);
		vim.w[window].__mkv_table_overflow_updating = nil;
	end

	vim.w[window].__mkv_table_overflow_wrap = nil;
	vim.w[window].__mkv_table_overflow_buffer = nil;
	vim.w[window].__mkv_table_overflow_active = nil;

	dbg.log("table-overflow", ("window=%d restored_wrap=%s"):format(
		window,
		tostring(vim.wo[window].wrap)
	));
end

--- Restores all windows currently showing `buffer`.
---@param buffer integer
table_overflow.restore = function (buffer)
	if type(buffer) ~= "number" then
		return;
	end

	for _, window in ipairs(vim.api.nvim_list_wins()) do
		if vim.w[window].__mkv_table_overflow_buffer == buffer then
			table_overflow.restore_window(window);
		end
	end
end

--- Restores every window modified by horizontal table mode.
table_overflow.restore_all = function ()
	for _, window in ipairs(vim.api.nvim_list_wins()) do
		table_overflow.restore_window(window);
	end
end

return table_overflow;
