local nvim_data_dir = vim.fn.stdpath("data")
local rootPath = nvim_data_dir .. "/dbridge.nvim"
local connectionsPath = rootPath .. "/connections"
M = {}

local init = function()
	if vim.fn.isdirectory(rootPath) == 0 then
		vim.fn.mkdir(rootPath)
	end
	if vim.fn.isdirectory(connectionsPath) == 0 then
		vim.fn.mkdir(connectionsPath)
	end
end

init()

local defaultConfig = { serverUrl = "http://localhost:3695/", connectionsPath = connectionsPath }

M = vim.tbl_extend("keep", M, defaultConfig)

return M
