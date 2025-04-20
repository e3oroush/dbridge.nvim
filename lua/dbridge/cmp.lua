local dbridge = require("dbridge")
local dbconnection = require("dbridge.dbconnection")
local Api = require("dbridge.api")
local source = {}

-- Constructor for the source
-- This will help to create multiple independent instances of the source object
function source:new()
	return setmetatable({}, { __index = self })
end

function source:setup(opt)
	self.configs = opt
end

-- Check if the source is available for the current buffer
function source:is_available()
	return vim.bo.filetype == "sql"
end

-- complete function
function source:complete(params, callback)
	--- The following only handles one database and and one schema
	--- if we have more than one database or schema, we should handle it differently
	local q = params.context.cursor_before_line
	local conId = dbridge.getActiveConnectionId()
	local dbCatolog = dbconnection.getAllDbCatalogs(conId)
	local tables = {}
	local items = {}
	local dbname = "db"
	local schema = "schema"
	if #dbCatolog == 1 then
		local schemas = dbCatolog[1].schemas
		dbname = dbCatolog[1].name
		if #schemas == 1 then
			tables = schemas[1].tables
			schema = schemas[1].name
		end
	end
	-- count the number of dots
	local _, cnt = string.gsub(q, "%.", "%.")
	if cnt == 0 then
		-- if we're looking for tables
		for _, value in ipairs(tables) do
			table.insert(items, {
				label = value,
				detail = "Table in " .. dbname .. "." .. schema,
				type = NodeUtils.NodeTypes.TABLE,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
			})
		end
	elseif cnt == 1 then
		-- if we're looking for columns
		local tableName = vim.split(q, "%.")[1]
		local columns = Api.getRequest(Api.path.getColumns .. Api.pathArgs, { conId = conId, tableName = tableName })
		for _, column in ipairs(columns) do
			table.insert(items, {
				label = column,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
				type = NodeUtils.NodeTypes.COLUMN,
				detail = "column in table " .. tableName,
			})
		end
	end
	callback({ items = items, isInComplete = false })
end

-- Resolve function to add additional information for each item
function source:resolve(item, callback)
	callback(item)
end

return source
