local config = require("dbridge.config")
M = {}
--- compute connection path for the given connection name
---@param name string
---@return string
M.getConnectionPath = function(name)
	return config.connectionsPath .. "/" .. name
end
--- compute queries path for the given connection name
---@param name string
---@return string
M.getQueriesPath = function(name)
	return config.queriesPath .. "/" .. name
end

return M
