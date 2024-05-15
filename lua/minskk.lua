local M = {
  curr_state = nil,
  is_enabled = false,
}

local direct_input_kana_state = require 'state/direct-input-kana'
local direct_input_hfc_state = require 'state/direct-input-hfc'
local input_reading_state = require 'state/input-reading'
local select_kanji_state = require 'state/select-kanji'

local function go_to_direct_input_hfc_state()
  M.curr_state = direct_input_hfc_state
  M.curr_state.enter()
end

local function go_to_direct_input_kana_state()
  M.curr_state = direct_input_kana_state
  M.curr_state.enter()
end

local function go_to_input_reading_state(inst)
  M.curr_state = input_reading_state
  M.curr_state.enter(inst)
end

local function go_to_select_kanji_state(inst)
  M.curr_state = select_kanji_state
  return M.curr_state.enter(inst)
end

function M.enable()
  if not M.is_enabled then
    vim.cmd('startinsert')
    M.is_enabled = true
    go_to_direct_input_hfc_state()
  end
end

local function disable()
  if M.is_enabled then
    M.is_enabled = false
    vim.cmd('stopinsert')
  end
end

function M.init()
  vim.api.nvim_set_keymap("n", "<C-j>", "<ESC>:MinSKKEnable<CR>", { silent = true })

  vim.keymap.set("i", "<C-j>", function() M.curr_state.handle_ctrl_j() end, {})
  vim.keymap.set("i", "<BS>", function() M.curr_state.handle_bs() end, {})
  vim.keymap.set("i", "<C-h>", function() M.curr_state.handle_bs() end, {})
  vim.keymap.set("i", "<ESC>", function() M.curr_state.handle_esc() end, {})
  vim.keymap.set("i", "<CR>", function() M.curr_state.handle_cr() end, {})

  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    callback = M.enable,
  })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    pattern = "*",
    callback = function()
      if M.is_enabled then
        vim.v.char = M.curr_state.handle_input(vim.v.char)
      end
    end,
  })

  M.curr_state = direct_input_hfc_state

  -- initialize dfa
  local dfa = {
    go_to_direct_input_hfc_state = go_to_direct_input_hfc_state,
    go_to_direct_input_kana_state = go_to_direct_input_kana_state,
    go_to_input_reading_state = go_to_input_reading_state,
    go_to_select_kanji_state = go_to_select_kanji_state,
  }
  local bs = vim.api.nvim_replace_termcodes("<BS>", true, false, true)
  local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)

  local util = {
    bs = bs,
    cr = cr,
    disable = disable,
  }
  direct_input_hfc_state.init(dfa, util)
  direct_input_kana_state.init(dfa, util)
  input_reading_state.init(dfa, util)
  select_kanji_state.init(dfa, util)
end

vim.cmd [[
  command! MinSKKEnable lua require 'minskk'.enable()
]]

return M

