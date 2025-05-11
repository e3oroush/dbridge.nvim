local FileUtils = require("dbridge.file_utils")
local M = {}

--- Extracts the SQL query surrounding the cursor in the specified buffer.
--- @param bufnr number|nil Buffer number (defaults to current buffer if nil)
--- @param cursor table|nil Cursor position {row, col} (0-based); defaults to current cursor if nil
--- @return string The extracted SQL query
function M.getSqlQuery(bufnr, cursor)
	-- Default to current buffer and cursor position if not provided
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	cursor = cursor or vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2] -- Convert row to 0-based

	-- Get all buffer lines
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if #lines == 0 then
		return ""
	end

	--- Find the nearest semicolon or boundary in the given direction
	--- @param start_row number 0-based row to start from
	--- @param start_col number 0-based column to start from
	--- @param direction string "backward" or "forward"
	--- @return number, number Row and column (0-based) of the boundary
	local function findBoundry(start_row, start_col, direction)
		local current_row, current_col = start_row, start_col

		while true do
			local line = lines[current_row + 1] -- Lua is 1-based
			local search_col = direction == "backward" and current_col or current_col + 1
			local found_col

			if direction == "backward" then
				found_col = line:reverse():find(";", #line - search_col + 1)
				if found_col then
					found_col = #line - found_col
				end
			else
				found_col = line:find(";", search_col)
				if found_col then
					found_col = found_col - 1 -- Point to the semicolon
				end
			end

			if found_col then
				return current_row, found_col
			end

			-- Move to next/previous line or stop at boundary
			if direction == "backward" then
				if current_row == 0 then
					return 0, 0
				end
				current_row = current_row - 1
				current_col = #lines[current_row + 1]
			else
				if current_row == #lines - 1 then
					return #lines - 1, #lines[#lines]
				end
				current_row = current_row + 1
				current_col = 0
			end
		end
	end

	-- Determine query start (after previous semicolon or file start)
	local start_row, start_col
	if row == 0 and col == 0 then
		start_row, start_col = 0, 0
	else
		start_row, start_col = findBoundry(row, col, "backward")
		if start_col ~= 0 then
			if start_col < #lines[start_row + 1] then
				start_col = start_col + 1 -- Move past semicolon
			else
				start_row = start_row + 1
				start_col = 0
			end
		end
	end

	-- Determine query end (at next semicolon or file end)
	local end_row, end_col
	if row == #lines - 1 and col == #lines[#lines] then
		end_row, end_col = #lines - 1, #lines[#lines]
	else
		end_row, end_col = findBoundry(row, col, "forward")
	end

	-- Extract the query text
	local query_lines = {}
	for i = start_row, end_row do
		local line = lines[i + 1]
		local s_col = (i == start_row) and start_col or 0
		local e_col = (i == end_row) and end_col or #line
		table.insert(query_lines, line:sub(s_col + 1, e_col))
	end

	return table.concat(query_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "") -- Trim leading/trailing whitespace
end

--- Depending on the cursor position determines if we should return column name or not
--- If it's false, it means we should suggest table, schema or db names as completions
--- @param bufnr number|nil Buffer number (defaults to current buffer if nil)
--- @param cursor table|nil Cursor position {row, col} (0-based); defaults to current cursor if nil
--- @return boolean
M.isGetColumns = function(bufnr, cursor)
	-- Default to current buffer and cursor position if not provided
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	cursor = cursor or vim.api.nvim_win_get_cursor(0)
	-- Get lines up to the cursor (limit to 5 lines before for performance)
	local start_line = math.max(0, cursor[1] - 5)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, cursor[1] + 1, false)
	if not lines or #lines == 0 then
		return false
	end
	-- Get the current line up to the cursor
	local current_line = lines[#lines]
	local col = cursor[2] + 1 -- Convert to 1-based for string indexing
	current_line = current_line:sub(1, col - 1) -- Text before cursor
	lines[#lines] = current_line

	-- Join lines, strip whitespace and newlines, and normalize to lowercase
	local text_before = table.concat(lines, " "):gsub("%s+", " "):lower()
	if text_before == "" then
		return false
	end
	-- Split into words (non-whitespace sequences)
	local words = {}
	for word in text_before:gmatch("%w+") do
		table.insert(words, word)
	end
	local line = lines[#lines]
	if not line then
		return false
	end
	for i = #words, 1, -1 do
		local word = words[i]
		if word == "select" then
			return true
		elseif word == "from" then
			return false
		elseif word == "where" then
			return true
		end
	end
	-- -- Get the character under the cursor
	-- local char_under_cursor = line:sub(col - 1, col)
	--
	-- -- Get the last word before the cursor
	-- local last_word = words[#words]
	-- if char_under_cursor:match("%S") ~= nil then
	-- 	-- if the character under the cursor is not space, it means it might be a column name
	-- 	if #words < 2 then
	-- 		return false
	-- 	elseif last_word == "from" then
	-- 		return false
	-- 	end
	-- 	last_word = words[#words - 1]
	-- else
	-- 	if not last_word then
	-- 		return false
	-- 	end
	-- end
	-- return last_word == "select"
end
local function strip(str)
	if not str then
		return ""
	end
	return str:gsub("^%s+", ""):gsub("%s+$", "")
end
--- Extract tabel name using python script
--- For this function dbridge python lib needs to be installed
--- It will call dbridge.scripts.extract_table query
--- @param sqlStatement string a select query in string
--- @return string table name or empty string
M.extractTable = function(sqlStatement)
	local cmd = "echo " .. sqlStatement .. " | python -m dbridge.scripts.extract_table "
	local output = FileUtils.runCmd(cmd)
	return strip(output)
end

return M
