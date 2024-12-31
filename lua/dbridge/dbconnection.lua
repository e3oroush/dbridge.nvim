local api = require("dbridge.api")
local Popup = require("nui.popup")
local Config = require("dbridge.config")
local event = require("nui.utils.autocmd").event
M = {}

local function getPopup(onEnter, onLeave)
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
				bottom = "q to exit",
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
	popup:on(event.BufWinEnter, function()
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

--- Connects to the dbridge server and returns the uuid connection
---@param config table
---@return string
M.addConnection = function(config)
	local conConfigRet = api.postRequest("connections", config)
	local conConfig = vim.fn.json_decode(conConfigRet)
	return conConfig.connection_id
end
M.getTables = function(conId)
	local result = api.getRequest("get_tables?connection_id=$conId", { conId = conId })
	return vim.json.decode(result)
end
local function initText()
	local config = { name = "test_db", adapter = "sqlite", uri = "" }
	return vim.fn.json_encode(config)
end

M.newDbConnection = function(applyConfig)
	local function getInputConfig(lines)
		local content = table.concat(lines, "\n")
		local config = vim.fn.json_decode(content)
		applyConfig(config)
	end
	local popup = getPopup(initText, getInputConfig)
	popup:mount()
end

M.getStoredConnections = function()
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

return M
