local Api = require("dbridge.api")
local NodeUtils = require("dbridge.node_utils")
local FileUtils = require("dbridge.file_utils")
local Popup = require("nui.popup")
local Config = require("dbridge.config")
local Event = require("nui.utils.autocmd").event
DbConnection = {}

---@class connectionConfig
---@field name string
---@field conId string
---@field uri string
---@field storedQueriesNodeId string

---@class DatabaseCatalog
---@field name string
---@field schemas Schema[]

---@class Schema
---@field name string
---@field tables string[]

local function getPopUp()
	local popup = Popup({
		position = "50%",
		size = {
			width = 40,
			height = 10,
		},
		enter = true,
		focusable = true,
		zindex = 50,
		relative = "editor",
		border = {
			padding = {
				top = 1,
				bottom = 1,
				left = 1,
				right = 1,
			},
			style = "rounded",
			text = {
				top = " Enter db configurations ",
				top_align = "center",
				bottom = "q to save and exit",
				bottom_align = "left",
			},
		},
		buf_options = {
			modifiable = true,
			readonly = false,
		},
		win_options = {
			winblend = 10,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
		},
	})
	popup:map("n", "q", ":q<CR>")
	return popup
end
local function getNewConPopup(onEnter, onLeave)
	local popup = getPopUp()
	popup:on(Event.BufWinEnter, function()
		if onEnter ~= nil then
			local text = onEnter()
			local lines = vim.split(text, "\n", { plain = true })
			vim.api.nvim_set_option_value("filetype", "json", { buf = popup.bufnr })
			vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
		end
	end)
	popup:on("BufLeave", function()
		if onLeave ~= nil then
			local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
			onLeave(lines)
		end
		popup:unmount()
	end)
	return popup
end

DbConnection.editConnection = function(connectionConfig)
	local conPath = NodeUtils.getConnectionPath(connectionConfig.name)
	local popup = getPopUp()
	local content = vim.fn.readfile(conPath)
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, content)
	popup:on("BufLeave", function()
		local editedConfig = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
		vim.fn.writefile(editedConfig, conPath)
	end)
	popup:map("n", "q", function()
		popup:unmount()
	end)
	popup:mount()
end

--- Connects to the dbridge server and returns the uuid connection
---@param config table
---@return string
DbConnection.addConnection = function(config)
	local conConfig = Api.postRequest("connections", config)
	return conConfig.connection_id
end
DbConnection.getTables = function(conId)
	return Api.getRequest(Api.path.getTables .. "?connection_id=$conId", { conId = conId })
end
--- Get all databases with their schema and tables using the current connection user credentials
---@param conId string
---@return DatabaseCatalog[]
DbConnection.getAllDbCatalogs = function(conId)
	return Api.getRequest(Api.path.getAll .. "?connection_id=$conId", { conId = conId })
end
local function initText()
	local config = { name = "test_db", adapter = "sqlite", uri = "" }
	return vim.fn.json_encode(config)
end

DbConnection.newDbConnection = function(applyConfig)
	local function getInputConfig(lines)
		local content = table.concat(lines, "\n")
		local config = vim.fn.json_decode(content)
		applyConfig(config)
	end
	local popup = getNewConPopup(initText, getInputConfig)
	popup:mount()
end

DbConnection.getStoredConnections = function()
	local dirPath = Config.connectionsPath
	local handle = vim.uv.fs_scandir(dirPath)
	local connections = {}
	while true do
		local name, type = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end

		-- Ensure only files are opened
		if type == "file" then
			local filePath = dirPath .. "/" .. name
			local content = vim.fn.readfile(filePath)
			table.insert(connections, vim.fn.json_decode(content))
		end
	end
	return connections
end

--- Save a new connection config. It also create an empty directory for the query path
---@param connectionConfig connectionConfig
DbConnection.saveConnection = function(connectionConfig)
	local conConfigPath = NodeUtils.getConnectionPath(connectionConfig.name)
	local queryPath = NodeUtils.getQueryPath(connectionConfig.name)
	local file = io.open(conConfigPath, "w")
	if file then
		file:write(vim.fn.json_encode(connectionConfig))
		file:close()
	end
	FileUtils.safeMkdir(queryPath)
end
return DbConnection
