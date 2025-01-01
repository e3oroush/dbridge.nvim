local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")
local Config = require("dbridge.config")
NodeUtils = {}
--- compute connection path for the given connection name
---@param name string
---@return string
NodeUtils.getConnectionPath = function(name)
	return Config.connectionsPath .. "/" .. name
end
--- compute queries path for the given connection name
---@param name string
---@return string
NodeUtils.getQueryPath = function(name)
	return Config.queriesPath .. "/" .. name
end

--- returns nuitree node for a saved query file
---@param fileName string
---@return NuiTreeNode
NodeUtils.getSavedQueryNode = function(fileName)
	return NuiTree.Node({ text = " " .. fileName, savedQuery = fileName })
end

--- Create a tree of connections with default mappings
---@param panel NuiSplit
---@return NuiTree tree the created tree
NodeUtils.createTreeNode = function(panel)
	local map_options = { noremap = true, nowait = true }
	local tree = NuiTree({
		winid = panel.winid,
		bufnr = panel.bufnr,
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

	panel:map("n", "l", function()
		local node = tree:get_node()

		if node ~= nil and node:expand() then
			tree:render()
		end
	end, map_options)

	panel:map("n", "h", function()
		local node = tree:get_node()
		if node == nil then
			return
		end

		if node:collapse() then
			tree:render()
		end
	end, map_options)
	return tree
end
--- Toggles tree node between expansion and collapse
---@param node NuiTreeNode
NodeUtils.toggleNodeExpansion = function(node)
	if node:is_expanded() then
		node:collapse()
	else
		node:expand()
	end
end

--- callapse all root nodes of the given tree
---@param tree NuiTree
NodeUtils.collapseRootNodes = function(tree)
	local rootNodes = tree:get_nodes()
	for _, rootNode in ipairs(rootNodes) do
		rootNode:collapse()
	end
end

--- Traverse the tree and find the root connection node and retuns it
---@param node NuiTreeNode
---@param tree NuiTree
---@return NuiTreeNode root
NodeUtils.getRootNode = function(node, tree)
	local root = node
	while root.connectionConfig == nil do
		local parentId = root:get_parent_id()
		local parent = tree:get_node(parentId)
		if parent == nil then
			break
		else
			root = parent
		end
	end
	return root
end
return NodeUtils
