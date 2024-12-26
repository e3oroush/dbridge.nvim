M = {}

local defaultConfig = { serverUrl = "http://localhost:8000/" }

M = vim.tbl_extend("keep", M, defaultConfig)

return M
