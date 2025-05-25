local fileUtils = require("dbridge.file_utils")
local nvim_data_dir = vim.fn.stdpath("data")
local rootPath = nvim_data_dir .. "/dbridge.nvim"
local connectionsPath = rootPath .. "/connections"
local queriesPath = rootPath .. "/queries"
local Config = {}

local init = function()
	fileUtils.safeMkdir(rootPath)
	fileUtils.safeMkdir(rootPath)
	fileUtils.safeMkdir(queriesPath)
	fileUtils.safeMkdir(connectionsPath)
end

init()

local defaultConfig = {
	serverUrl = "http://localhost:3695/",
	connectionsPath = connectionsPath,
	queriesPath = queriesPath,
	isEnabled = true,
}
-- this will make sure if the current run time has dbridge python package installed
local retCode = tonumber(vim.trim(fileUtils.runCmd("python -c 'import dbridge' 2> /dev/null; echo $?")))
if retCode ~= 0 then
	defaultConfig.isEnabled = false
end

Config = vim.tbl_extend("keep", Config, defaultConfig)

return Config
