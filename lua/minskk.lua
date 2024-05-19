local M = {
  curr_state = nil,
  is_enabled = false,
}

local g_common = require 'common'

local DFAState = {
  DirectInput_FWC = 1,
  DirectInput_HWC = 2,
  DirectInput_Hiragana = 3,
  DirectInput_Katakana = 4,
  InputReading_Reading = 5,
  InputReading_AcKana = 6,
  SelectKanji = 7,
}

local direct_input_kana_state = require 'state/direct-input-kana'
local direct_input_hwc_state = require 'state/direct-input-hwc'
local direct_input_fwc_state = require 'state/direct-input-fwc'
local input_reading_state = require 'state/input-reading'
local select_kanji_state = require 'state/select-kanji'

local function go_to_direct_input_hwc_state()
  M.curr_state = direct_input_hwc_state
  M.curr_state.enter()
end

local function go_to_direct_input_fwc_state()
  M.curr_state = direct_input_fwc_state
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
    go_to_direct_input_hwc_state()
  end
end

local function disable()
  if M.is_enabled then
    M.is_enabled = false
    vim.cmd('stopinsert')
  end
end

local function set_dfa_state(state)
  local msg
  if state == DFAState.DirectInput_FWC then
    msg = '全角英数'
  elseif state == DFAState.DirectInput_HWC then
    msg = '半角英数'
  elseif state == DFAState.DirectInput_Hiragana then
    msg = 'ひらがな'
  elseif state == DFAState.DirectInput_Katakana then
    msg = 'カタカナ'
  elseif state == DFAState.InputReading_Reading then
    msg = '漢字読み入力'
  elseif state == DFAState.InputReading_AcKana then
    msg = '送り仮名入力'
  elseif state == DFAState.SelectKanji then
    msg = '漢字変換'
  end
  g_common.alert(msg)
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

  M.curr_state = direct_input_hwc_state

  local dfa = {
    go_to_direct_input_hwc_state = go_to_direct_input_hwc_state,
    go_to_direct_input_fwc_state = go_to_direct_input_fwc_state,
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
    set_dfa_state = set_dfa_state,
    DFAState = DFAState,
  }
  direct_input_hwc_state.init(dfa, util)
  direct_input_fwc_state.init(dfa, util)
  direct_input_kana_state.init(dfa, util)
  input_reading_state.init(dfa, util)
  select_kanji_state.init(dfa, util)
end

vim.cmd [[
  command! MinSKKEnable lua require 'minskk'.enable()
]]

return M

