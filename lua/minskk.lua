local M = {
  curr_state = nil,
  is_enabled = false,
}

local g_common = require 'common'

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

local function go_to_input_reading_state()
  M.curr_state = input_reading_state
  M.curr_state.enter()
end

local function go_to_select_kanji_state(exit_immediately, letter)
  M.curr_state = select_kanji_state
  exit_immediately = (exit_immediately or false)
  return M.curr_state.enter(exit_immediately, letter)
end

function M.enable()
  if M.is_enabled then
    go_to_direct_input_kana_state()
    return
  else
    M.is_enabled = true
    go_to_direct_input_hfc_state()
  end
end

local function disable()
  if M.is_enabled then
    M.is_enabled = false
    g_common.alert("MinSKK disabled")
  end
end

local function on_key_press(key)
  -- exit if not in insert mode
  if vim.fn.mode() ~= "i" then
    return
  end

  if key == vim.api.nvim_replace_termcodes("<Esc>", true, false, true) then
    disable()
    return
  end
end

function M.init()
  vim.api.nvim_set_keymap("n", "<C-j>", "<ESC>:MinSKKEnable<CR>", {})
  vim.keymap.set("i", "<C-j>", function() M.curr_state.handle_ctrl_j() end, {})
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

  local ns_id = vim.api.nvim_create_namespace("minskk_namespace")
  vim.on_key(on_key_press, ns_id)

  -- initialize dfa
  local dfa = {
    go_to_direct_input_hfc_state = go_to_direct_input_hfc_state,
    go_to_direct_input_kana_state = go_to_direct_input_kana_state,
    go_to_input_reading_state = go_to_input_reading_state,
    go_to_select_kanji_state = go_to_select_kanji_state,
  }
  direct_input_hfc_state.init(dfa)
  direct_input_kana_state.init(dfa)
  input_reading_state.init(dfa)
  select_kanji_state.init(dfa)
end

vim.cmd [[
  command! MinSKKEnable lua require 'minskk'.enable()
]]

return M

