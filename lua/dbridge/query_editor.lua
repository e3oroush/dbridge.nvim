local Split = require("nui.split")
local Api = require("dbridge.api")
local NodeUtils = require("dbridge.node_utils")
QueryEditor = {}

--- read the query file and open it into main panel buffer
---@param node NuiTreeNode
---@param tree NuiTree
QueryEditor.openSavedQery = function(node, tree)
	local rootNode = NodeUtils.getRootNode(node, tree)
	local queryPath = NodeUtils.getQueryPath(rootNode.connectionConfig.name) .. "/" .. node.savedQuery
	local content = vim.fn.readfile(queryPath)
	local bufnr = QueryEditor.panel.bufnr
	local winid = QueryEditor.panel.winid
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_buf_set_name(bufnr, queryPath)
	vim.api.nvim_set_current_win(winid)
	vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

--- add a new saved query
---@param node NuiTreeNode
---@param tree NuiTree
QueryEditor.addSavedQuery = function(node, tree)
	local parentNodeId = node:get_parent_id()
	local rootNode = NodeUtils.getRootNode(node, tree)
	local fileName = rootNode.connectionConfig.name .. "-" .. os.date("%Y-%m-%d-%H%M%S") .. ".sql"
	local queryPath = NodeUtils.getQueryPath(rootNode.connectionConfig.name) .. "/" .. fileName
	vim.fn.writefile({}, queryPath)
	local savedQueryNode = NodeUtils.getSavedQueryNode(fileName)
	QueryEditor.tree:add_node(savedQueryNode, parentNodeId)
	QueryEditor.tree:render()
	QueryEditor.openSavedQery(savedQueryNode, tree)
end
---@param node NuiTreeNode
---@param tree NuiTree
QueryEditor.clearQueryWindow = function(node, tree)
	local bufnr = QueryEditor.panel.bufnr
	local winid = QueryEditor.panel.winid
	local rootNode = NodeUtils.getRootNode(node, tree)
	local fileName = rootNode.connectionConfig.name .. "-" .. os.date("%Y-%m-%d-%H%M%S") .. ".sql"
	local queryPath = NodeUtils.getQueryPath(rootNode.connectionConfig.name) .. "/" .. fileName
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_name(bufnr, queryPath)
	vim.api.nvim_set_current_win(winid)
	vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

--- Execte the query written in the current buffer
---@param conId string|nil connection id
---@return table result is the json string resulted from executed query
QueryEditor.executeQuery = function(conId)
	local lines = vim.api.nvim_buf_get_lines(QueryEditor.panel.bufnr, 0, -1, false)
	local query = table.concat(lines or {}, "\n")
	-- TODO: try to connect if selectedDbConfig is nil
	local data = { query = query, connection_id = conId }
	local result = Api.postRequest("run_query", data)
	return result
end
QueryEditor.init = function()
	-- make the buffer sql like file for lsp and formatting
	local panel = Split({
		buf_options = { filetype = "sql", buftype = "", bufhidden = "wipe", swapfile = false },
	})
	-- make the buffer exit without saving
	panel:on("QuitPre", function()
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = panel.bufnr })
	end)
	QueryEditor.panel = panel
end
return QueryEditor
