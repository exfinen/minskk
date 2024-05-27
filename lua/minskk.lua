local M = {
  curr_state = nil,
  is_enabled = false,
}

local DFAState = {
  Disabled = 1,
  DirectInput_FWC = 2,
  DirectInput_Hiragana = 3,
  DirectInput_Katakana = 4,
  InputReading_Reading = 5,
  InputReading_AcKana = 6,
  SelectKanji = 7,
  SelectKanjiList = 8,
  RegisterWord = 9,
}

local direct_input_kana_state = require 'state/direct-input-kana'
local direct_input_fwc_state = require 'state/direct-input-fwc'
local input_reading_state = require 'state/input-reading'
local select_kanji_state = require 'state/select-kanji'
local select_kanji_list_state = require 'state/select-kanji-list'
local register_word_state = require 'state/register-word'

local status = require 'status'

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

local function go_to_select_kanji_list_state(inst)
  M.curr_state = select_kanji_list_state
  return M.curr_state.enter(inst)
end

local function go_to_register_word_state(inst)
  M.curr_state = register_word_state
  return M.curr_state.enter(inst)
end

function M.enable()
  if not M.is_enabled then
    vim.keymap.set("i", "<C-j>", function() M.curr_state.handle_ctrl_j() end, {})
    vim.keymap.set("i", "<BS>", function() M.curr_state.handle_bs() end, {})
    vim.keymap.set("i", "<C-h>", function() M.curr_state.handle_bs() end, {})
    vim.keymap.set("i", "<ESC>", function() M.curr_state.handle_esc() end, {})
    vim.keymap.set("i", "<CR>", function() M.curr_state.handle_cr() end, {})

    M.is_enabled = true
    go_to_direct_input_kana_state()
  end
end

local function set_ctrl_j_keymap()
  vim.api.nvim_set_keymap("i", "<C-j>", "<C-o>:MinSKKEnable<CR>", { silent = true })
end

local function disable()
  if M.is_enabled then
    set_ctrl_j_keymap()
    vim.keymap.del("i", "<BS>")
    vim.keymap.del("i", "<C-h>")
    vim.keymap.del("i", "<ESC>")
    vim.keymap.del("i", "<CR>")

    status.set('-')
    M.is_enabled = false
  end
end

local function set_dfa_state(state)
  if state == DFAState.DirectInput_FWC then
    status.set('全角英数')
  elseif state == DFAState.DirectInput_Hiragana then
    status.set('ひらがな')
  elseif state == DFAState.DirectInput_Katakana then
    status.set('カタカナ')
  elseif state == DFAState.InputReading_Reading then
    status.set('漢字読み')
  elseif state == DFAState.InputReading_AcKana then
    status.set('送り仮名')
  elseif state == DFAState.SelectKanji then
    status.set('漢字変換')
  elseif state == DFAState.SelectKanjiList then
    status.set('漢字キー変換')
  elseif state == DFAState.RegisterWord then
    status.set('単語登録')
  end
end

function M.apply_settings_override(settings)
  local mo = vim.g.minskk_override
  if mo then
    if mo.dict_file_path then
      settings.dict_file_path = mo.dict_file_path
    end
  end
end

function M.init()
  set_ctrl_j_keymap()

  vim.api.nvim_create_autocmd("InsertCharPre", {
    pattern = "*",
    callback = function()
      if M.is_enabled then
        vim.v.char = M.curr_state.handle_input(vim.v.char)
      end
    end,
  })

  M.curr_state = direct_input_kana_state

  local dfa = {
    go_to_direct_input_fwc_state = go_to_direct_input_fwc_state,
    go_to_direct_input_kana_state = go_to_direct_input_kana_state,
    go_to_input_reading_state = go_to_input_reading_state,
    go_to_select_kanji_state = go_to_select_kanji_state,
    go_to_select_kanji_list_state = go_to_select_kanji_list_state,
    go_to_register_word_state = go_to_register_word_state,
  }
  local bs = vim.api.nvim_replace_termcodes("<BS>", true, false, true)
  local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)

  local util = {
    bs = bs,
    cr = cr,
    disable = disable,
    set_dfa_state = set_dfa_state,
    DFAState = DFAState,
    status = status,
  }
  direct_input_fwc_state.init(dfa, util)
  direct_input_kana_state.init(dfa, util)
  input_reading_state.init(dfa, util)
  select_kanji_state.init(dfa, util)
  select_kanji_list_state.init(dfa, util)
  register_word_state.init(dfa, util)

  -- default settings
  local settings = {
    dict_file_path = '~/.skk/SKK-JISYO.L',
    user_dict_file_path = '~/.skk/user-dict',
  }
  -- override defult settings if needed
  M.apply_settings_override(settings)

  select_kanji_state.build_dict(settings.dict_file_path)
  register_word_state.set_user_dict(settings.user_dict_file_path)
end

function _G.minskk_statusline()
  return status.get()
end

vim.cmd [[
  command! MinSKKEnable lua require 'minskk'.enable()
]]

return M

