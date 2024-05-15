-- state to handle half-width character input

local M = {}

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.enter()
  M.util.set_dfa_state(M.util.DFAState.DirectInput_HWC)
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
  M.util.disable()
end

function M.handle_input(c)
  return c
end

return M

