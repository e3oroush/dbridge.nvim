local dbridge = require("dbridge")
local dbconnection = require("dbridge.dbconnection")
local Api = require("dbridge.api")
local SqlExtractor = require("dbridge.sql_extractor")
local Config = require("dbridge.config")

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
	if not Config.isEnabled then
		return
	end
	local q = params.context.cursor_before_line
	local sqlStatement = SqlExtractor.getSqlQuery()
	local tableNameInSqlStatement = SqlExtractor.extractTable(sqlStatement)
	local doGetColumns = SqlExtractor.isGetColumns()
	local conId = Config.connectionId
	local dbCatalog = Config.currentDbCatalog
	local items = {}
	local function insertTable(tableName, schemaName)
		table.insert(items, {
			label = tableName,
			detail = "Table in " .. schemaName,
			type = NodeUtils.NodeTypes.TABLE,
			kind = vim.lsp.protocol.CompletionItemKind.Property,
		})
	end

	local function insertSchema(schemaName, dbname)
		table.insert(items, {
			label = schemaName,
			detail = "Schema in " .. dbname,
			type = NodeUtils.NodeTypes.SCHEMA,
			kind = vim.lsp.protocol.CompletionItemKind.Property,
		})
	end
	local function insertDb(dbname)
		table.insert(items, {
			label = dbname,
			detail = "Database",
			type = NodeUtils.NodeTypes.DATABASE,
			kind = vim.lsp.protocol.CompletionItemKind.Property,
		})
	end
	local function insertColumns(tableName, schemaName)
		local columns = Api.getRequest(
			Api.path.getColumns .. Api.pathArgs,
			{ conId = conId, tableName = tableName, schemaName = schemaName }
		)
		for _, column in ipairs(columns) do
			table.insert(items, {
				label = column,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
				type = NodeUtils.NodeTypes.COLUMN,
				detail = "column in table " .. tableName,
			})
		end
	end

	-- initializing the table dbnames, schema names and table names
	-- TODO: the schema names and table names should be dependent on the current connection
	-- meaning, if a schema is selected, we only return the tables on that schema
	local tables = {}
	local dbnames = {}
	local schemas = {}
	local columns = {}
	for _, db in ipairs(dbCatalog) do
		table.insert(dbnames, db.name)
		local cols = Api.getRequest(
			Api.path.getAllColumns .. Api.pathArgs,
			{ conId = conId, tableName = nil, schemaName = nil, dbname = db.name }
		)
		for _, col in ipairs(cols) do
			table.insert(columns, col)
		end
		for _, sc in ipairs(db.schemas) do
			table.insert(schemas, db.name .. "." .. sc.name)
			for _, tbl in ipairs(sc.tables) do
				table.insert(tables, db.name .. "." .. sc.name .. "." .. tbl)
			end
		end
	end
	-- the logic is to determine whether return column name or table name
	if doGetColumns then
		if #tableNameInSqlStatement > 0 then
			-- TODO: exclude the columns in the sql statement from all columns
			local tblName = containsString(tables, tableNameInSqlStatement)
			if tblName then
				local parts = vim.split(tblName, "%.")
				insertColumns(parts[3], parts[2])
			end
		else
			-- all columns
			for _, column in ipairs(columns) do
				local parts = vim.split(column, "%.")
				table.insert(items, {
					label = parts[2],
					kind = vim.lsp.protocol.CompletionItemKind.Property,
					type = NodeUtils.NodeTypes.COLUMN,
					detail = "column in table " .. parts[1],
				})
			end
		end
	else
		-- return dbnames, schema or table names
		local qParts = vim.split(q, " ")
		-- count the number of dots from the word under the cursor
		local queryParts = vim.split(qParts[#qParts], "%.")
		if #queryParts == 1 then
			-- there's no dot (.)
			-- if we're looking for tables
			for _, value in ipairs(tables) do
				local parts = vim.split(value, "%.")
				insertTable(parts[3], parts[1] .. "." .. parts[2])
			end
			-- if we're looking for schemas
			for _, value in ipairs(schemas) do
				local parts = vim.split(value, "%.")
				insertSchema(parts[2], parts[1])
			end
			-- if we're looking for databases
			for _, value in ipairs(dbnames) do
				local parts = vim.split(value, "%.")
				insertDb(parts[1])
			end
		elseif #queryParts == 2 then
			-- there's one dot
			local firstPart = queryParts[1]
			local dbnameItem = containsString(dbnames, firstPart)
			local schemaItem = containsString(schemas, firstPart)
			local tableItem = containsString(tables, firstPart)
			if dbnameItem then
				-- first part is a db name
				for _, schema in ipairs(schemas) do
					local parts = vim.split(schema, "%.")
					if isSubstr(firstPart, parts[1]) then
						insertSchema(parts[2], firstPart)
					end
				end
			elseif schemaItem then
				-- first part is a schema
				for _, tblName in ipairs(tables) do
					local parts = vim.split(tblName, "%.")
					if isSubstr(firstPart, parts[2]) then
						insertTable(parts[3], parts[1] .. "." .. parts[2])
					end
				end
			elseif tableItem then
				-- first part is a table
				-- we're looking for columns
				local parts = vim.split(tableItem, "%.")
				insertColumns(parts[3], parts[2])
			end
		elseif #queryParts == 3 then
			-- there's two dots
			local firstPart = queryParts[1]
			local secondPart = queryParts[2]
			local dbnameItem = containsString(dbnames, firstPart)
			local schemaItem = containsString(schemas, firstPart)
			if dbnameItem then
				-- first part is a db name
				for _, tblName in ipairs(tables) do
					local parts = vim.split(tblName, "%.")
					if isSubstr(secondPart, parts[2]) then
						insertTable(parts[3], parts[1] .. "." .. parts[2])
					end
				end
			elseif schemaItem then
				-- first part is a schema name
				insertColumns(secondPart, firstPart)
			end
		elseif #queryParts == 4 then
			local secondPart = queryParts[2]
			local thirdPart = queryParts[3]
			insertColumns(thirdPart, secondPart)
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
