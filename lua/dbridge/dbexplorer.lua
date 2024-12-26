local Layout = require("nui.layout")
local NuiLine = require("nui.line")
local Split = require("nui.split")
local NuiTree = require("nui.tree")
local api = require("dbridge.api")
local dbconnection = require("dbridge.dbconnection")
local queryResult = require("dbridge.query_result")

M = {}

M.hide = true
M.selectedDbConfig = {}
local function getPanels()
	local left_panel = Split({})
	local bottom_panel = Split({})
	local main_panel = Split({})
	return { left_panel = left_panel, bottom_panel = bottom_panel, main_panel = main_panel }
end

M.init = function()
	-- print("call init function")
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

	panels.left_panel:map("n", "<CR>", function()
		local node = tree:get_node()
		if node == nil then
			return
		end
		if node.connectionConfig then
			if not node.loaded then
				local uri = node.connectionConfig.uri
				local adapter = node.connectionConfig.adapter
				local tables = dbconnection.addConnection(uri, adapter)
				for _, tableName in ipairs(tables) do
					tree:add_node(
						NuiTree.Node({
							text = tableName,
							get_columns_query = "get_columns?uri=$uri&table_name=$tableName",
							get_table_query = "query_table?uri=$uri&table_name=$tableName",
							args = { uri = uri, tableName = tableName },
							loaded = false,
						}),
						node:get_id()
					)
				end
				node.loaded = true
			end
			M.selectedDbConfig = node.connectionConfig
		end
		if node.get_columns_query ~= nil and not node.loaded then
			local nodes = api.getRequest(node.get_columns_query, node.args)
			local nodesList = vim.json.decode(nodes)
			for _, child in ipairs(nodesList) do
				tree:add_node(NuiTree.Node({ text = child }), node:get_id())
			end
			node.loaded = true
			node:expand()
			tree:render()
		end
		if node.get_table_query ~= nil then
			local result = api.getRequest(node.get_table_query, node.args)
			local tbl = queryResult.getTable(vim.json.decode(result), panels.bottom_panel)
			tbl:render()
		end
	end, map_options)

	panels.main_panel:map("n", "<leader>r", function()
		local lines = vim.api.nvim_buf_get_lines(panels.main_panel.bufnr, 0, -1, false)
		local query = table.concat(lines or {}, "\n")
		-- TODO: try to connect if selectedDbConfig is nil
		local data = { query = query, uri = M.selectedDbConfig.uri }
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
		local function applyConfig(connectionConfig)
			print("applyConfig")
			M.addNewRootNode(connectionConfig)
			tree:render()
		end
		dbconnection.newDbConnection(applyConfig)
		-- local nodeId = M.addNewRootNode(connectionConfig)
		-- local tables = dbconnection.addConnection(uri)
		-- for _, tableName in ipairs(tables) do
		-- 	tree:add_node(
		-- 		NuiTree.Node({
		-- 			text = tableName,
		-- 			get_columns_query = "get_columns?uri=$uri&table_name=$tableName",
		-- 			get_table_query = "query_table?uri=$uri&table_name=$tableName",
		-- 			args = { uri = uri, tableName = tableName },
		-- 			loaded = false,
		-- 		}),
		-- 		nodeId
		-- 	)
		-- end
	end, { buffer = panels.left_panel.bufnr })
	M.panels = panels
	M.tree = tree
	M.layout = layout
end

M.init()

M.addNewRootNode = function(connectionConfig)
	local node = NuiTree.Node({
		text = connectionConfig.name,
		connectionConfig = connectionConfig,
		loaded = false,
	})
	M.tree:add_node(node, nil)
	M.tree:render()
	return node:get_id()
end

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

return M
