local NuiTable = require("nui.table")
local Split = require("nui.split")
local Text = require("nui.text")

QueryResult = {}

QueryResult.renderResult = function(dataStr)
	local data = vim.json.decode(dataStr)
	local columns = {}
	local panel = QueryResult.panel
	-- just show the top 5
	local topn = vim.fn.min({ 5, #data })
	data = vim.list_slice(data, 1, topn)
	-- data is an array of tables with key=value for table
	for k, _ in pairs(data[1]) do
		local col = {
			align = "center",
			header = k,
			accessor_key = k,
			cell = function(cell)
				return Text(tostring(cell.get_value()), "DiagnosticInfo")
			end,
		}
		table.insert(columns, col)
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = panel.bufnr })
	vim.api.nvim_buf_set_lines(panel.bufnr, 0, -1, false, {})
	vim.api.nvim_set_option_value("modifiable", false, { buf = panel.bufnr })
	local tbl = NuiTable({
		bufnr = panel.bufnr,
		ns_id = panel.ns_id,
		columns = columns,
		data = data,
	})
	tbl:render()
end

QueryResult.init = function()
	QueryResult.panel = Split({})
end
return QueryResult
