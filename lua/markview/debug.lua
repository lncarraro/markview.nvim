local M = {};

local _log_path = vim.fn.stdpath("state") .. "/markview_debug.log";

M.log = function (tag, msg)
	local f = io.open(_log_path, "a");
	if f then
		f:write(os.date("%H:%M:%S") .. " [" .. tag .. "] " .. msg .. "\n");
		f:close();
	end
end;

M.clear = function ()
	local f = io.open(_log_path, "w");
	if f then f:close(); end
end;

return M;
