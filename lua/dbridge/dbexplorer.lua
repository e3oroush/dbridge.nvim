local Split = require("nui.split")
local NuiTree = require("nui.tree")
local Api = require("dbridge.api")
local Dbconnection = require("dbridge.dbconnection")
local FileUtils = require("dbridge.file_utils")
local NodeUtils = require("dbridge.node_utils")

DbExplorer = {}

--- returns a table with Nodes of saved queries stored on disk
---@param connectionConfig connectionConfig
---@return NuiTreeNode[] nodes a table that has a list nodes for saved query
local function getSavedQueries(connectionConfig)
	local dirPath = NodeUtils.getQueryPath(connectionConfig.name)
	local queryFiles = FileUtils.getFilesInDirectory(dirPath)
	local nodes =
		{ NuiTree.Node({ text = " New query", addQuery = true, nodeType = NodeUtils.NodeTypes.NEW_SAVED_QUERY }) }
	for _, fileName in ipairs(queryFiles) do
		table.insert(nodes, NodeUtils.getSavedQueryNode(fileName))
	end
	return nodes
end

--- Returns the node under cursor or nil if no node is selected
---@return NuiTreeNode | nil
DbExplorer.getNodeOnCursor = function()
	return DbExplorer.tree:get_node()
end

--- get the root node that is expanded. this node is the connection node and it has the connectionConfig on it
---@return NuiTreeNode | nil
DbExplorer.getExpandedRootNode = function()
	local rootNodes = DbExplorer.tree:get_nodes()
	local rootNode = nil
	for _, node in ipairs(rootNodes) do
		if node:is_expanded() then
			if node.connectionConfig then
				rootNode = node
				break
			end
		end
	end
	return rootNode
end

--- When user enter to a new connection node. this function creates the connection to the server and prepare all the required queries
---@param node NuiTreeNode
local function handleEnterConnectionNode(node)
	-- first colapse all nodes
	NodeUtils.collapseRootNodes(DbExplorer.tree)
	if not node.loaded then
		local storedQueriesNode = NodeUtils.NewNodeFactory(
			" " .. "Saved queries",
			NodeUtils.NodeTypes.ROOT_SAVED_QUERY,
			nil,
			getSavedQueries(node.connectionConfig)
		)
		-- store the node id of the special stored queries node
		node.connectionConfig.storedQueriesNodeId = storedQueriesNode:get_id()
		DbExplorer.tree:add_node(storedQueriesNode, node:get_id())
		local conId = Dbconnection.addConnection(node.connectionConfig)
		node.connectionConfig.conId = conId
		local allDbCatalogs = DbConnection.getAllDbCatalogs(conId)
		for _, dbCataolg in ipairs(allDbCatalogs) do
			local dbname = dbCataolg.name
			local dbNode = NodeUtils.NewNodeFactory(" " .. dbname, NodeUtils.NodeTypes.DATABASE)
			DbExplorer.tree:add_node(dbNode, node:get_id())
			for _, schema in ipairs(dbCataolg.schemas) do
				local schemaName = schema.name
				local schemaNode = NodeUtils.NewNodeFactory("󰢶 " .. schemaName, NodeUtils.NodeTypes.SCHEMA)
				DbExplorer.tree:add_node(schemaNode, dbNode:get_id())
				for _, tblName in ipairs(schema.tables) do
					DbExplorer.tree:add_node(
						NodeUtils.NewNodeFactory(" " .. tblName, NodeUtils.NodeTypes.TABLE, {
							get_columns_query = "get_columns?connection_id=$conId&table_name=$tableName",
							get_table_query = "query_table?connection_id=$conId&table_name=$tableName",
							args = { conId = conId, tableName = tblName },
							loaded = false,
						}),
						schemaNode:get_id()
					)
				end
			end
		end
		node.loaded = true
	end
	-- set the cursor at the begginig of the buffer
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	NodeUtils.toggleNodeExpansion(node)
	DbExplorer.tree:render()
end
--- Get table names from server and create tree node
---@param node NuiTreeNode
local function handleGetTableColumns(node)
	local nodesList = Api.getRequest(node.get_columns_query, node.args)
	for _, child in ipairs(nodesList) do
		DbExplorer.tree:add_node(NodeUtils.NewNodeFactory(" " .. child, NodeUtils.NodeTypes.COLUMN), node:get_id())
	end
	node.loaded = true
	NodeUtils.toggleNodeExpansion(node)
	DbExplorer.tree:render()
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
	local resultedReturn = { node = node }
	if node.nodeType == NodeUtils.NodeTypes.CONNECTION then
		handleEnterConnectionNode(node)
	end
	if node.nodeType == NodeUtils.NodeTypes.TABLE then
		if node.get_columns_query ~= nil and not node.loaded then
			handleGetTableColumns(node)
		end
	end
	-- the following node types only toggle the expansion
	if
		node.nodeType == NodeUtils.NodeTypes.ROOT_SAVED_QUERY
		or node.nodeType == NodeUtils.NodeTypes.SCHEMA
		or node.nodeType == NodeUtils.NodeTypes.DATABASE
	then
		NodeUtils.toggleNodeExpansion(node)
		DbExplorer.tree:render()
	end
	-- if node.savedQuery then
	-- 	resultedReturn.saveQueryNode = true
	-- end
	-- if node.addQuery then
	-- 	resultedReturn.addQueryNode = true
	-- end
	return resultedReturn
end

--- Add a new root node as a new connection to the connection tree in the dbexplorer
---@param connectionConfig table
---@return string
local addNewRootNode = function(connectionConfig)
	local node = NodeUtils.NewNodeFactory(
		"󱘖 " .. connectionConfig.name,
		NodeUtils.NodeTypes.CONNECTION,
		{ connectionConfig = connectionConfig, loaded = false }
	)
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
local function initTree()
	DbExplorer.tree = NodeUtils.createTreeNode(DbExplorer.panel)
	initStoredConnections()
end
local function init()
	DbExplorer.panel = Split({ enter = true })
	initTree()
end
DbExplorer.addNewRootNode = addNewRootNode
DbExplorer.init = init
DbExplorer.handleEditConnection = function()
	local node = DbExplorer.tree:get_node()
	if node == nil then
		return
	end
	if node.connectionConfig then
		Dbconnection.editConnection(node.connectionConfig, function(newConConfig)
			node.connectionConfig = newConConfig
			node.text = "󱘖 " .. newConConfig.name
			DbExplorer.tree:render()
		end)
	end
end
return DbExplorer
