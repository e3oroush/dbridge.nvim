local config = require("dbridge.config")
local dbexplorer = require("dbridge.dbexplorer")
local M = {}
M.setup = function(opts)
	opts = opts or {}
	config = vim.tbl_extend("keep", opts, config)
end

-- vim.api.nvim_create_user_command("DbridgeCurrentConnection", , { desc = "Shows the selected connection" })

return M
