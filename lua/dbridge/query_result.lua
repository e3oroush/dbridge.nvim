local NuiTable = require("nui.table")
local Text = require("nui.text")

M = {}

M.getTable = function(data, panel)
	local columns = {}
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
	local tbl = NuiTable({
		bufnr = panel.bufnr,
		ns_id = panel.ns_id,
		columns = columns,
		data = data,
	})
	return tbl
end

return M
