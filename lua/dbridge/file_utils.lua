FileUtils = {}
--- Scan a given directory and returns all the files inside it (excluding directories)
---@param dirPath string
---@return string[] files table as a list of file names inside dir
FileUtils.getFilesInDirectory = function(dirPath)
	local handle = vim.uv.fs_scandir(dirPath)
	local files = {}
	while true do
		local name, type = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end

		-- Ensure only files are opened
		if type == "file" then
			table.insert(files, name)
		end
	end
	return files
end
--- @param path string
--- @param flags? string
--- @param prot? any
FileUtils.safeMkdir = function(path, flags, prot)
	flags = flags or ""
	prot = prot or "0o755"
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, flags, prot)
	end
end
return FileUtils
