local fileUtils = require("dbridge.file_utils")
local nvim_data_dir = vim.fn.stdpath("data")
local rootPath = nvim_data_dir .. "/dbridge.nvim"
local connectionsPath = rootPath .. "/connections"
local queriesPath = rootPath .. "/queries"
Config = {}

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
}

Config = vim.tbl_extend("keep", Config, defaultConfig)

return Config
