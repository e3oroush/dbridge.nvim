local config = require("dbridge.config")
Api = {}

Api.path = { getAll = "get_dbs_schemas_tables", getTables = "get_tables" }
local url = config.serverUrl
local function runCmd(cmd)
	local handle = io.popen(cmd)
	assert(handle ~= nil, "coudln't open io.popen to run command")
	-- Read the output
	local result = handle:read("*a")
	-- Close the handle
	handle:close()
	return result
end
Api.getRequest = function(path, args)
	args = args or {}
	for k, v in pairs(args) do
		path = string.gsub(path, "%$" .. k, vim.fn.shellescape(v))
	end
	local getUrl = url .. path
	local cmd = "curl --silent --no-buffer -X GET '" .. getUrl .. "'"
	return vim.fn.json_decode(runCmd(cmd))
end
Api.postRequest = function(path, data)
	local cmd = "curl --silent --no-buffer -X POST " .. url .. path .. " -H 'Content-Type: application/json'"
	if data ~= nil then
		local body = vim.fn.json_encode(data)
		cmd = cmd .. " -d '$body'"
		cmd = string.gsub(cmd, "%$body", body)
	end
	return vim.fn.json_decode(runCmd(cmd))
end

return Api
