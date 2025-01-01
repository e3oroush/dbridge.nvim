local Layout = require("nui.layout")
local NuiLine = require("nui.line")
local Split = require("nui.split")
local NuiTree = require("nui.tree")
local Popup = require("nui.popup")
local api = require("dbridge.api")
local dbconnection = require("dbridge.dbconnection")
local queryResult = require("dbridge.query_result")
local config = require("dbridge.config")
local fileUtils = require("dbridge.file_utils")
local nodeUtils = require("dbridge.node_utils")

M = {}

M.hide = true
M.selectedDbConfig = {}
local function getPanels()
	local left_panel = Split({})
	local bottom_panel = Split({})
	-- make the buffer sql like file for lsp and formatting
	local main_panel = Split({
		buf_options = { filetype = "sql", buftype = "", bufhidden = "wipe", swapfile = false },
	})
	-- make the buffer exit without saving
	main_panel:on("QuitPre", function()
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = main_panel.bufnr })
	end)
	return { left_panel = left_panel, bottom_panel = bottom_panel, main_panel = main_panel }
end

local function saveConnection(connectionConfig)
	local configPath = config.connectionsPath .. "/" .. connectionConfig.name
	local queryPath = config.queriesPath .. "/" .. connectionConfig.name
	local file = io.open(configPath, "w")
	if file then
		file:write(vim.fn.json_encode(connectionConfig))
		file:close()
	end
	config.safeMkdir(queryPath)
end
local function applyConfig(connectionConfig)
	M.addNewRootNode(connectionConfig)
	saveConnection(connectionConfig)
	M.tree:render()
end

local function initStoredConnections()
	local connections = dbconnection.getStoredConnections()
	for _, con in ipairs(connections) do
		M.addNewRootNode(con)
	end
	M.tree:render()
end

--- returns nuitree node for a saved query file
---@param fileName string
---@return NuiTreeNode
local function getSavedQueryNode(fileName)
	return NuiTree.Node({ text = " " .. fileName, savedQuery = fileName })
end

--- returns a table with Nodes of saved queries stored on disk
---@param connectionConfig table
---@return table
local function getSavedQueries(connectionConfig)
	local dirPath = nodeUtils.getQueriesPath(connectionConfig.name)
	local queryFiles = fileUtils.getFilesInDirectory(dirPath)
	local nodes = { NuiTree.Node({ text = " New query", addQuery = true }) }
	for _, fileName in ipairs(queryFiles) do
		table.insert(nodes, getSavedQueryNode(fileName))
	end
	return nodes
end

--- Returns the active connection name
---@return string | nil
local function getActiveConnectionName()
	local selected = nil
	if M.selectedDbConfig ~= nil then
		selected = M.selectedDbConfig.name
	end
	return selected
end

local function getPopupConfig()
	local popup = Popup({
		position = "50%",
		size = {
			width = 60,
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
				top = " Connection config ",
				top_align = "center",
				bottom = "q to save and exit",
				bottom_align = "left",
			},
		},
		buf_options = {
			modifiable = true,
			readonly = false,
			buftype = "",
			bufhidden = "hide",
			swapfile = true,
			filetype = "json",
		},
		win_options = {
			winblend = 10,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
		},
	})
	return popup
end

local function collapseRootNodes()
	-- colapse all nodes
	local rootNodes = M.tree:get_nodes()
	for _, rootNode in ipairs(rootNodes) do
		rootNode:collapse()
	end
end

--- Toggles tree node between expansion and collapse
---@param node NuiTreeNode
local function toggleNodeExpansion(node)
	if node:is_expanded() then
		node:collapse()
	else
		node:expand()
	end
end

--- read the query file and open it into main panel buffer
---@param node NuiTreeNode
local function openSavedQery(node)
	-- TODO: maybe using the parent node config name would be a better idea
	local queryPath = nodeUtils.getQueriesPath(M.selectedDbConfig.name) .. "/" .. node.savedQuery
	local content = vim.fn.readfile(queryPath)
	local bufnr = M.panels.main_panel.bufnr
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_buf_set_name(bufnr, queryPath)
	vim.api.nvim_set_current_win(M.panels.main_panel.winid)
	vim.api.nvim_win_set_cursor(M.panels.main_panel.winid, { 1, 0 })
end

--- add a new saved query
---@param parentNodeId string?
local function addSavedQuery(parentNodeId)
	local fileName = M.selectedDbConfig.name .. "-" .. os.date("%Y-%m-%d-%H%M%S") .. ".sql"
	local queryPath = nodeUtils.getQueriesPath(M.selectedDbConfig.name) .. "/" .. fileName
	vim.fn.writefile({}, queryPath)
	local node = getSavedQueryNode(fileName)
	M.tree:add_node(node, parentNodeId)
	M.tree:render()
	openSavedQery(node)
end

local function clearQueryWindow()
	local bufnr = M.panels.main_panel.bufnr
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_name(bufnr, "")
	vim.api.nvim_set_current_win(M.panels.main_panel.winid)
	vim.api.nvim_win_set_cursor(M.panels.main_panel.winid, { 1, 0 })
end

M.init = function()
	local map_options = { noremap = true, nowait = true }
	local panels = getPanels()

	local layout = Layout(
		{
			position = "top",
			size = "100%",
			relative = "editor",
		},
		Layout.Box({
			Layout.Box({
				Layout.Box(panels.left_panel, { size = "20%" }),
				Layout.Box(panels.main_panel, { size = "80%" }),
			}, { dir = "row", size = "100%" }),
			Layout.Box(panels.bottom_panel, { size = "20%" }),
		}, { dir = "col", size = "100%" })
	)

	local tree = NuiTree({
		winid = panels.left_panel.winid,
		bufnr = panels.left_panel.bufnr,
		nodes = {},
		prepare_node = function(node)
			local line = NuiLine()

			line:append(string.rep("  ", node:get_depth() - 1))

			if node:has_children() then
				line:append(node:is_expanded() and " " or " ", "SpecialChar")
			else
				line:append("  ")
			end

			line:append(node.text)

			return line
		end,
	})

	panels.left_panel:map("n", "l", function()
		local node = tree:get_node()

		if node ~= nil and node:expand() then
			tree:render()
		end
	end, map_options)

	panels.left_panel:map("n", "h", function()
		local node = tree:get_node()
		if node == nil then
			return
		end

		if node:collapse() then
			tree:render()
		end
	end, map_options)
	panels.left_panel:map("n", "e", function()
		local node = tree:get_node()
		if node == nil then
			return
		end
		if node.connectionConfig then
			local path = config.connectionsPath .. "/" .. node.connectionConfig.name
			local popup = getPopupConfig()
			local content = vim.fn.readfile(path)
			vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, content)
			popup:on("BufLeave", function()
				local editedConfig = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
				vim.fn.writefile(editedConfig, path)
			end)
			popup:map("n", "q", function()
				popup:unmount()
			end)
			popup:mount()
		end
	end, map_options)

	panels.left_panel:map("n", "<CR>", function()
		local node = tree:get_node()
		if node == nil then
			return
		end
		-- if the node is a root data base
		if node.connectionConfig then
			-- first colapse all nodes
			collapseRootNodes()
			if not node.loaded then
				local storedQueriesNode = NuiTree.Node(
					{ text = " " .. "Saved queries", savedQueries = true },
					getSavedQueries(node.connectionConfig)
				)
				node.connectionConfig.storedQueriesNodeId = storedQueriesNode:get_id()
				tree:add_node(storedQueriesNode, node:get_id())
				local conId = dbconnection.addConnection(node.connectionConfig)
				node.connectionConfig.conId = conId
				local tables = dbconnection.getTables(conId)
				for _, tableName in ipairs(tables) do
					tree:add_node(
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
			toggleNodeExpansion(node)
			tree:render()
			M.selectedDbConfig = node.connectionConfig
		end
		-- if node is a table: fetch it columns and expand them
		if node.get_columns_query ~= nil and not node.loaded then
			local nodes = api.getRequest(node.get_columns_query, node.args)
			local nodesList = vim.json.decode(nodes)
			for _, child in ipairs(nodesList) do
				tree:add_node(NuiTree.Node({ text = child }), node:get_id())
			end
			node.loaded = true
			toggleNodeExpansion(node)
			tree:render()
		end
		-- if node is a table: query a sample data
		if node.get_table_query ~= nil then
			local result = api.getRequest(node.get_table_query, node.args)
			local tbl = queryResult.getTable(vim.json.decode(result), panels.bottom_panel)
			clearQueryWindow()
			tbl:render()
		end
		if node.savedQueries then
			toggleNodeExpansion(node)
			tree:render()
		end
		if node.savedQuery then
			openSavedQery(node)
		end
		if node.addQuery then
			local parentId = node:get_parent_id()
			addSavedQuery(parentId)
		end
	end, map_options)

	panels.main_panel:map("n", "<leader>r", function()
		local lines = vim.api.nvim_buf_get_lines(panels.main_panel.bufnr, 0, -1, false)
		local query = table.concat(lines or {}, "\n")
		-- TODO: try to connect if selectedDbConfig is nil
		local data = { query = query, connection_id = M.selectedDbConfig.conId }
		local result = api.postRequest("run_query", data)
		local tbl = queryResult.getTable(vim.json.decode(result), panels.bottom_panel)
		tbl:render()
	end, map_options)
	-- handle when user enter :q
	for _, panel in pairs(panels) do
		panel:on("BufUnload", function()
			vim.schedule(function()
				local currBuffer = vim.api.nvim_get_current_buf()
				for _, pn in pairs(panels) do
					if pn.bufnr == currBuffer then
						return
					end
				end
				layout:unmount()
				vim.g.dbridge_loaded = 0
				M.hide = true
				M.init()
			end)
		end)
	end
	vim.keymap.set("n", "a", function()
		dbconnection.newDbConnection(applyConfig)
	end, { buffer = panels.left_panel.bufnr })
	M.panels = panels
	M.tree = tree
	M.layout = layout
	initStoredConnections()
end

M.addNewRootNode = function(connectionConfig)
	local node = NuiTree.Node({
		text = "󱘖 " .. connectionConfig.name,
		connectionConfig = connectionConfig,
		loaded = false,
	})
	M.tree:add_node(node, nil)
	M.tree:render()
	return node:get_id()
end

M.init()
vim.api.nvim_create_user_command("Dbxplore", function()
	if vim.g.dbridge_loaded ~= 1 then
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

M.getActiveConnectionName = getActiveConnectionName
return M
