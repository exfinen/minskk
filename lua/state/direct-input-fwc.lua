-- state to handle full-width character input

local M = {}

local g_converter = require 'state/conv-map/zen-alphanum'
local g_common = require 'common'

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.enter()
  g_common.alert('Direct Input (Full-Width Chars)')
end

function M.handle_ctrl_j()
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_cr()
  vim.api.nvim_feedkeys(M.util.cr, "in", true)
end

function M.handle_bs()
  vim.api.nvim_feedkeys(M.util.bs, "in", true)
end

function M.handle_esc()
  g_common.alert("ESC in DI fwc")
  M.util.disable()
end

function M.handle_input(c)
  return g_converter.map(c)
end

return M

