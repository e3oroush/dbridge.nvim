local Split = require("nui.split")
HelpPanel = {}

--- initialize the help buffer
local function initPanel()
	local text = { "󰋖 Press ? for help." }
	vim.api.nvim_buf_set_lines(HelpPanel.panel.bufnr, 0, -1, false, text)
end
HelpPanel.init = function()
	HelpPanel.panel = Split({ enter = false })
	HelpPanel.show = false
	initPanel()
end

--- Toggles the help panel to show and hide the help message
HelpPanel.handleHelp = function()
	local winid = HelpPanel.panel.winid
	local currenHeith = vim.api.nvim_win_get_height(winid)
	local gap = 15
	if HelpPanel.show then
		vim.api.nvim_win_set_height(winid, currenHeith - gap)
		HelpPanel.show = false
		initPanel()
	else
		HelpPanel.show = true
		vim.api.nvim_win_set_height(winid, currenHeith + gap)
		local text = {
			"'?' to hide this.",
			"'a' add a new connection",
			"'e' edit a connection",
			"'Enter' open a connection",
			"'R' refresh a connection",
			"'DD' delete a connection/query",
			"'l' to expand an opened node",
			"'h' to collapse an expaned node",
			"'<leader>r' on editor execute query",
			"'n' on bottom panel next page",
			"'p' on bottom panel prev page",
		}
		vim.api.nvim_buf_set_lines(HelpPanel.panel.bufnr, 0, -1, false, text)
	end
end

return HelpPanel
