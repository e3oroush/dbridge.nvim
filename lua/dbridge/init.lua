local config = require("dbridge.config")
require("dbridge.dbexplorer")
local M = {}
M.setup = function(opts)
	opts = opts or {}
	config = vim.tbl_extend("keep", opts, config)
end

return M
