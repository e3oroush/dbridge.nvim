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

local function isSubstr(sub, str)
	return string.find(string.lower(str), string.lower(sub), 1, true) ~= nil
end
local function containsString(tbl, str)
	for _, value in ipairs(tbl) do
		if isSubstr(str, value) then
			return value
		end
	end
	return false
end

-- complete function
function source:complete(params, callback)
	--- The following only handles one database and and one schema
	--- if we have more than one database or schema, we should handle it differently
	local q = params.context.cursor_before_line
	-- TODO: get it from cache
	local conId = dbridge.getActiveConnectionId()
	-- a connId should have already some information for current db and schema
	-- we should use this information
	local dbCatalog = dbconnection.getAllDbCatalogs(conId)
	local tables = {}
	local items = {}
	local dbnames = {}
	local schemas = {}
	for _, db in ipairs(dbCatalog) do
		table.insert(dbnames, db.name)
		for _, sc in ipairs(db.schemas) do
			table.insert(schemas, db.name .. "." .. sc.name)
			for _, tbl in ipairs(sc.tables) do
				table.insert(tables, db.name .. "." .. sc.name .. "." .. tbl)
			end
		end
	end
	-- local dbname = "db"
	-- local schema = "schema"
	-- if #dbCatalog == 1 then
	-- 	local schemas = dbCatalog[1].schemas
	-- 	dbname = dbCatalog[1].name
	-- 	if #schemas == 1 then
	-- 		tables = schemas[1].tables
	-- 		schema = schemas[1].name
	-- 	end
	-- end
	-- count the number of dots
	local queryParts = vim.split(q, "%.")
	if #queryParts == 1 then
		-- if we're looking for tables
		for _, value in ipairs(tables) do
			local parts = vim.split(value, "%.")
			P(parts)
			table.insert(items, {
				label = parts[3],
				detail = "Table in " .. parts[1] .. "." .. parts[2],
				type = NodeUtils.NodeTypes.TABLE,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
			})
		end
		-- if we're looking for schemas
		for _, value in ipairs(schemas) do
			local parts = vim.split(value, "%.")
			table.insert(items, {
				label = parts[2],
				detail = "Schema in " .. parts[1],
				type = NodeUtils.NodeTypes.SCHEMA,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
			})
		end
		-- if we're looking for databases
		for _, value in ipairs(dbnames) do
			local parts = vim.split(value, "%.")
			table.insert(items, {
				label = parts[1],
				detail = "Database",
				type = NodeUtils.NodeTypes.DATABASE,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
			})
		end
	elseif #queryParts == 2 then
		local firstPart = queryParts[1]
		local dbnameItem = containsString(dbnames, firstPart)
		local schemaItem = containsString(schemas, firstPart)
		local tableItem = containsString(tables, firstPart)
		if dbnameItem then
			-- first part is a db name
			for _, schema in ipairs(schemas) do
				if isSubstr(firstPart, vim.split(schema, "%.")[1]) then
					table.insert(items, {
						label = vim.split(schema, "%.")[2],
						detail = "Schema in " .. firstPart,
						type = NodeUtils.NodeTypes.SCHEMA,
						kind = vim.lsp.protocol.CompletionItemKind.Property,
					})
				end
			end
		elseif schemaItem then
			-- first part is a schema
			for _, tblName in ipairs(tables) do
				local parts = vim.split(tblName, "%.")
				if isSubstr(firstPart, parts[2]) then
					table.insert(items, {
						label = parts[3],
						detail = "Table in " .. parts[1] .. "." .. parts[2],
						type = NodeUtils.NodeTypes.TABLE,
						kind = vim.lsp.protocol.CompletionItemKind.Property,
					})
				end
			end
		elseif tableItem then
			-- first part is a table
			-- we're looking for columns
			local parts = vim.split(tableItem, "%.")
			local columns = Api.getRequest(Api.path.getColumns .. Api.pathArgs, { conId = conId, tableName = parts[3] })
			for _, column in ipairs(columns) do
				table.insert(items, {
					label = column,
					kind = vim.lsp.protocol.CompletionItemKind.Property,
					type = NodeUtils.NodeTypes.COLUMN,
					detail = "column in table " .. parts[3],
				})
			end
		end
	end
	callback({ items = items, isInComplete = false })
end

-- Resolve function to add additional information for each item
-- for eg. add documentation
function source:resolve(item, callback)
	callback(item)
end

return source
