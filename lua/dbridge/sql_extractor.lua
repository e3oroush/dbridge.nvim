local M = {}

--- Extracts the SQL query surrounding the cursor in the specified buffer.
--- @param bufnr number|nil Buffer number (defaults to current buffer if nil)
--- @param cursor table|nil Cursor position {row, col} (0-based); defaults to current cursor if nil
--- @return string The extracted SQL query
function M.get_sql_query(bufnr, cursor)
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
	local function find_boundary(start_row, start_col, direction)
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
		start_row, start_col = find_boundary(row, col, "backward")
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
		end_row, end_col = find_boundary(row, col, "forward")
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

return M
