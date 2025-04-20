local M = {}
local item_types = { TABLE = "", COLUMN = "" }

M.build_format = function(entry, vim_item)
	local type = entry.completion_item.type
	vim_item.kind = item_types[type] .. " " .. type
	vim_item.menu = "[DBRIDGE]"
	return vim_item
end

return M
