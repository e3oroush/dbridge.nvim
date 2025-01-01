local Config = require("dbridge.config")
local Layout = require("nui.layout")
local Dbexplorer = require("dbridge.dbexplorer")
local QueryEditor = require("dbridge.query_editor")
local QueryResult = require("dbridge.query_result")
local Dbconnection = require("dbridge.dbconnection")
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
local function initKeyMappings()
	local mapOptions = { noremap = true, nowait = true }
	Dbexplorer.panel:map("n", "a", addNewConnection, mapOptions)
	Dbexplorer.panel:map("n", "e", Dbexplorer.handleEditConnection, mapOptions)
	Dbexplorer.panel:map("n", "<CR>", function()
		local resultedReturn = Dbexplorer.handleEnterNode()
		if resultedReturn == nil then
			return
		end
		-- the selected node is a connection node
		if resultedReturn.selectedDbConfig ~= nil then
			M.selectedDbConfig = resultedReturn.selectedDbConfig
		end
		-- the selected node is a table
		if resultedReturn.sampleData ~= nil then
			QueryResult.renderResult(resultedReturn.sampleData)
			QueryEditor.clearQueryWindow()
		end
		-- the selected node is saved query file
		if resultedReturn.saveQueryNode ~= nil then
			QueryEditor.openSavedQery(resultedReturn.saveQueryNode, Dbexplorer.tree)
		end
		if resultedReturn.addQueryNode ~= nil then
			QueryEditor.addSavedQuery(resultedReturn.addQueryNode, Dbexplorer.tree)
		end
	end, mapOptions)
	QueryEditor.panel:map("n", "<leader>r", function()
		local dataStr = QueryEditor.executeQuery(M.selectedDbConfig)
		QueryResult.renderResult(dataStr)
	end, Config.mapOptions)
end

--- Returns the active connection name
---@return string | nil
M.getActiveConnectionName = function()
	local selected = nil
	if M.selectedDbConfig ~= nil then
		selected = M.selectedDbConfig.name
	end
	return selected
end

M.init = function()
	Dbexplorer.init()
	QueryEditor.init()
	QueryResult.init()
	local layout = Layout(
		{
			position = "top",
			size = "100%",
			relative = "editor",
		},
		Layout.Box({
			Layout.Box({
				Layout.Box(Dbexplorer.panel, { size = "20%" }),
				Layout.Box(QueryEditor.panel, { size = "80%" }),
			}, { dir = "row", size = "100%" }),
			Layout.Box(QueryResult.panel, { size = "20%" }),
		}, { dir = "col", size = "100%" })
	)
	M.selectedDbConfig = nil
	M.layout = layout
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
				layout:unmount()
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
