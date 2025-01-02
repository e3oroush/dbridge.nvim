local Config = require("dbridge.config")
local Layout = require("nui.layout")
local Dbexplorer = require("dbridge.dbexplorer")
local QueryEditor = require("dbridge.query_editor")
local QueryResult = require("dbridge.query_result")
local Dbconnection = require("dbridge.dbconnection")
local HelpPanel = require("dbridge.help")
local M = {}
M.setup = function(opts)
	opts = opts or {}
	Config = vim.tbl_extend("keep", opts, Config)
end

local function applyConfig(connectionConfig)
	Dbexplorer.addNewRootNode(connectionConfig)
	Dbconnection.saveConnection(connectionConfig)
	Dbexplorer.tree:render()
end
local function addNewConnection()
	Dbconnection.newDbConnection(applyConfig)
end
--- returns the active connectionConfig based on the tree connection expansion
---@return connectionConfig|nil
local function getActiveConnection()
	local node = DbExplorer.getExpandedRootNode()
	if node == nil then
		return
	end
	return node.connectionConfig
end

--- Returns the active connection name
---@return string | nil
local function getActiveConnectionName()
	local selected = nil
	local connectionConfig = getActiveConnection()
	if connectionConfig ~= nil then
		selected = connectionConfig.name
	end
	return selected
end

--- Returns the active connection uri
---@return string | nil
local function getActiveConnectionConId()
	local selected = nil
	local connectionConfig = getActiveConnection()
	if connectionConfig ~= nil then
		selected = connectionConfig.conId
	end
	return selected
end
local function getBoxSplits()
	return Layout.Box({
		Layout.Box({
			Layout.Box(Dbexplorer.panel, { size = "90%" }),
			Layout.Box(HelpPanel.panel, { size = "10%" }),
		}, { dir = "col", size = "20%" }),
		Layout.Box({
			Layout.Box(QueryEditor.panel, { size = "60%" }),
			Layout.Box(QueryResult.panel, { size = "40%" }),
		}, { dir = "col", size = "80%" }),
	}, { dir = "row", size = "100%" })
end
--- Initialize the layout
local function initLayout()
	local box = getBoxSplits()
	local layout = Layout({
		position = "top",
		size = "100%",
		relative = "editor",
	}, box)
	return layout
end
local function initKeyMappings()
	local mapOptions = { noremap = true, nowait = true }
	Dbexplorer.panel:map("n", "a", addNewConnection, mapOptions)
	Dbexplorer.panel:map("n", "e", Dbexplorer.handleEditConnection, mapOptions)
	Dbexplorer.panel:map("n", "<CR>", function()
		local resultedReturn = Dbexplorer.handleEnterNode()
		if resultedReturn == nil then
			return
		end
		local node = resultedReturn.node
		-- the selected node is a table
		if node.nodeType == NodeUtils.NodeTypes.TABLE then
			if node.get_table_query ~= nil then
				local sampleData = Api.getRequest(node.get_table_query, node.args)
				QueryResult.renderResult(sampleData)
				QueryEditor.clearQueryWindow(node, DbExplorer.tree)
			end
		end
		-- the selected node is saved query file
		if node.nodeType == NodeUtils.NodeTypes.SAVED_QUERY then
			QueryEditor.openSavedQery(node, Dbexplorer.tree)
		end
		if node.nodeType == NodeUtils.NodeTypes.NEW_SAVED_QUERY then
			QueryEditor.addSavedQuery(node, Dbexplorer.tree)
		end
	end, mapOptions)
	QueryEditor.panel:map("n", "<leader>r", function()
		local data = QueryEditor.executeQuery(getActiveConnectionConId())
		QueryResult.renderResult(data)
	end, mapOptions)
	QueryResult.panel:map("n", "n", QueryResult.handleNext, mapOptions)
	QueryResult.panel:map("n", "p", QueryResult.handlePrev, mapOptions)
	HelpPanel.panel:map("n", "?", HelpPanel.handleHelp, mapOptions)
end

M.init = function()
	Dbexplorer.init()
	QueryEditor.init()
	QueryResult.init()
	HelpPanel.init()
	M.layout = initLayout()
	M.hide = false
	initKeyMappings()
	-- handle when user enter :q
	local panels = { Dbexplorer.panel, QueryEditor.panel, QueryResult.panel }
	for _, panel in pairs(panels) do
		panel:on("BufUnload", function()
			vim.schedule(function()
				local currBuffer = vim.api.nvim_get_current_buf()
				for _, pn in pairs(panels) do
					if pn.bufnr == currBuffer then
						return
					end
				end
				M.layout:unmount()
				vim.g.dbridge_loaded = 0
				M.hide = true
				M.init()
			end)
		end)
	end
end

vim.api.nvim_create_user_command("Dbxplore", function()
	if vim.g.dbridge_loaded ~= 1 then
		M.init()
		M.layout:mount()
		vim.g.dbridge_loaded = 1
		M.hide = false
		return
	end
	if M.hide then
		M.layout:show()
	else
		M.layout:hide()
	end
	M.hide = not M.hide
end, {})
return M
