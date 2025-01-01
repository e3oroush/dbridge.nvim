local Split = require("nui.split")
local NuiTree = require("nui.tree")
local Api = require("dbridge.api")
local Dbconnection = require("dbridge.dbconnection")
local FileUtils = require("dbridge.file_utils")
local NodeUtils = require("dbridge.node_utils")

DbExplorer = {}

--- returns a table with Nodes of saved queries stored on disk
---@param connectionConfig table
---@return NuiTreeNode[] nodes a table that has a list nodes for saved query
local function getSavedQueries(connectionConfig)
	local dirPath = NodeUtils.getQueryPath(connectionConfig.name)
	local queryFiles = FileUtils.getFilesInDirectory(dirPath)
	local nodes = { NuiTree.Node({ text = " New query", addQuery = true }) }
	for _, fileName in ipairs(queryFiles) do
		table.insert(nodes, NodeUtils.getSavedQueryNode(fileName))
	end
	return nodes
end

DbExplorer.handleEditConnection = function()
	local node = DbExplorer.tree:get_node()
	if node == nil then
		return
	end
	if node.connectionConfig then
		Dbconnection.editConnection(node.connectionConfig)
	end
end

--- When user enter to a new connection node. this function creates the connection to the server and prepare all the required queries
---@param node NuiTreeNode
---@return connectionConfig
local function handleEnterConnectionNode(node)
	-- first colapse all nodes
	NodeUtils.collapseRootNodes(DbExplorer.tree)
	if not node.loaded then
		local storedQueriesNode = NuiTree.Node(
			{ text = " " .. "Saved queries", savedQueries = true },
			getSavedQueries(node.connectionConfig)
		)
		-- store the node id of the special stored queries node
		node.connectionConfig.storedQueriesNodeId = storedQueriesNode:get_id()
		DbExplorer.tree:add_node(storedQueriesNode, node:get_id())
		local conId = Dbconnection.addConnection(node.connectionConfig)
		node.connectionConfig.conId = conId
		local tables = Dbconnection.getTables(conId)
		for _, tableName in ipairs(tables) do
			DbExplorer.tree:add_node(
				NuiTree.Node({
					text = " " .. tableName,
					get_columns_query = "get_columns?connection_id=$conId&table_name=$tableName",
					get_table_query = "query_table?connection_id=$conId&table_name=$tableName",
					args = { conId = conId, tableName = tableName },
					loaded = false,
				}),
				node:get_id()
			)
		end
		node.loaded = true
	end
	-- set the cursor at the begginig of the buffer
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	NodeUtils.toggleNodeExpansion(node)
	DbExplorer.tree:render()
	return node.connectionConfig
end
--- Get table names from server and create tree node
---@param node NuiTreeNode
local function handleGetTableColumns(node)
	local nodes = Api.getRequest(node.get_columns_query, node.args)
	local nodesList = vim.json.decode(nodes)
	for _, child in ipairs(nodesList) do
		DbExplorer.tree:add_node(NuiTree.Node({ text = child }), node:get_id())
	end
	node.loaded = true
	NodeUtils.toggleNodeExpansion(node)
	DbExplorer.tree:render()
end
--- Executes the get query to fetch sample data from selected table and returns the json string result
---@param node NuiTreeNode
---@return string
local function handleQuerySampleDataTable(node)
	local result = Api.getRequest(node.get_table_query, node.args)
	return result
	-- local tbl = queryResult.getTable(vim.json.decode(result), panels.bottom_panel)
	-- clearQueryWindow()
	-- tbl:render()
end
--- Handles actions and cases when user hit enter in a node
--- There are different cases need to be handled. When user enter:
--- Connection node
--- Saved query node
--- New saved query node
--- Table node
--- Column node
--- ...
---@return table|nil
DbExplorer.handleEnterNode = function()
	local node = DbExplorer.tree:get_node()
	if node == nil then
		return
	end
	local resultedReturn = {}
	if node.connectionConfig then
		resultedReturn.selectedDbConfig = handleEnterConnectionNode(node)
	end
	if node.get_columns_query ~= nil and not node.loaded then
		handleGetTableColumns(node)
	end
	if node.get_table_query ~= nil then
		resultedReturn.sampleData = handleQuerySampleDataTable(node)
	end
	if node.savedQueries then
		NodeUtils.toggleNodeExpansion(node)
		DbExplorer.tree:render()
	end
	if node.savedQuery then
		resultedReturn.saveQueryNode = node
	end
	if node.addQuery then
		resultedReturn.addQueryNode = node
	end
	return resultedReturn
end

--- Add a new root node as a new connection to the connection tree in the dbexplorer
---@param connectionConfig table
---@return string
local addNewRootNode = function(connectionConfig)
	local node = NuiTree.Node({
		text = "󱘖 " .. connectionConfig.name,
		connectionConfig = connectionConfig,
		loaded = false,
	})
	DbExplorer.tree:add_node(node, nil)
	DbExplorer.tree:render()
	return node:get_id()
end

--- Initializes the tree with previously saved stored connections
local function initStoredConnections()
	local connections = Dbconnection.getStoredConnections()
	for _, con in ipairs(connections) do
		addNewRootNode(con)
	end
	DbExplorer.tree:render()
end
local function init()
	DbExplorer.panel = Split({})
	DbExplorer.tree = NodeUtils.createTreeNode(DbExplorer.panel)
	initStoredConnections()
end
DbExplorer.addNewRootNode = addNewRootNode
DbExplorer.init = init
return DbExplorer
