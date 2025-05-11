local config = require("dbridge.config")
local FileUtils = require("dbridge.file_utils")
local Api = {}
local cache = {}
--- Get value from cache or runCmd and cache it
--- @param cmd string
--- @return table json encoded return of the api call
local function getFromCache(cmd)
	local value = cache[cmd]
	if value then
		return value
	end
	value = vim.fn.json_decode(FileUtils.runCmd(cmd))
	cache[cmd] = value
	return value
end

Api.path = {
	getAll = "get_dbs_schemas_tables",
	getColumns = "get_columns",
	queryTable = "query_table",
	connection = "connections",
}
Api.pathArgs = "?connection_id=$conId&table_name=$tableName&dbname=$dbname&schema_name=$schemaName"
local url = config.serverUrl
Api.getRequest = function(path, args)
	args = args or {}
	for k, v in pairs(args) do
		path = string.gsub(path, "%$" .. k, vim.fn.shellescape(v))
	end
	local getUrl = url .. path
	local cmd = "curl --silent --no-buffer -X GET '" .. getUrl .. "'"
	return getFromCache(cmd)
end
Api.postRequest = function(path, data)
	local cmd = "curl --silent --no-buffer -X POST " .. url .. path .. " -H 'Content-Type: application/json'"
	if data ~= nil then
		local body = vim.fn.json_encode(data)
		body = string.gsub(body, "'", "'\"'")
		cmd = cmd .. " -d '" .. body .. "'"
	end
	return getFromCache(cmd)
end
Api.clearCache = function()
	cache = {}
end

return Api
