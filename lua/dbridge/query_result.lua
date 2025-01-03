local NuiTable = require("nui.table")
local Split = require("nui.split")
local Text = require("nui.text")

QueryResult = {}

local function getTotalPages()
	return math.ceil(QueryResult.totalItems / QueryResult.pageItems)
end

local function initPageStats(data)
	data = data or {}
	QueryResult.totalItems = #data or 0
	QueryResult.pageNr = 0
	QueryResult.data = data
end

local function getSliceData()
	local topn = vim.fn.min({ QueryResult.pageItems, QueryResult.totalItems })
	local first = QueryResult.pageNr * QueryResult.pageItems
	return vim.list_slice(QueryResult.data, first + 1, topn + first)
end

local function renderData(data)
	local columns = {}
	local panel = QueryResult.panel
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

QueryResult.renderResult = function(data)
	initPageStats(data)
	-- just show a limited items
	local sliceData = getSliceData()
	-- data is an array of tables with key=value for table
	renderData(sliceData)
end

QueryResult.handleNext = function()
	if QueryResult.pageNr <= getTotalPages() then
		QueryResult.pageNr = QueryResult.pageNr + 1
		local sliceData = getSliceData()
		-- data is an array of tables with key=value for table
		renderData(sliceData)
	else
		vim.notify("Last page. No more data")
	end
end

QueryResult.handlePrev = function()
	if QueryResult.pageNr > 0 then
		QueryResult.pageNr = QueryResult.pageNr - 1
		local sliceData = getSliceData()
		-- data is an array of tables with key=value for table
		renderData(sliceData)
	else
		vim.notify("First page. Can't go back")
	end
end
QueryResult.init = function()
	QueryResult.panel = Split({ enter = false })
	QueryResult.pageItems = 5
	initPageStats()
end
return QueryResult
