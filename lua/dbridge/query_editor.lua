M = {}

M.prepareBuffer = function(bufnr)
	local randomName = os.tmpname()
	vim.api.nvim_set_option_value("filetype", "sql", { buf = bufnr })
	vim.api.nvim_buf_set_name(bufnr, randomName)
end

return M
