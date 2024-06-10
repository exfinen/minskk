M = {
  stack = {},
}

local g_common = require 'common'

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.is_empty()
  return #M.stack == 0
end

function M.push(session)
  table.insert(M.stack, session)
end

function M.pop()
  if #M.stack > 0 then
    return table.remove(M.stack)
  else
    return nil
  end
end

function M.peek()
  if #M.stack > 0 then
    return M.stack[#M.stack]
  else
    return nil
  end
end

function M.handle_cr()
  if M.is_empty() then
    vim.api.nvim_feedkeys(M.util.cr, "in", true)
  else
    M.register_word()
  end
end

function M.try_to_insert_bs()
  vim.schedule(function ()
    local session = M.peek()
    if not session then
      vim.api.nvim_feedkeys(M.util.bs, "in", true)
    else
      local pos, _ = g_common.get_curr_pos_w_line()
      if pos > session.beg_pos then
        vim.api.nvim_feedkeys(M.util.bs, "in", true)
      end
    end
  end)
end

local function add_to_user_dict(kanji, reading, ac_kana_first_char)
  -- write to user dict file
  reading = g_common.join_str_array(reading)
  local suffix = ac_kana_first_char == ' ' and '' or '*' .. ac_kana_first_char
  g_common.alert(
    string.format('%s%s -> %s', reading, suffix, kanji), 5000
  )
end

function M.register_word()
  vim.schedule(function ()
    local session = M.util.regist_mgr.pop()

    -- get the word user entered from the buffer
    local end_pos, line = g_common.get_curr_pos_w_line()
    local word = string.sub(line, session.beg_pos, end_pos) -- end inclusive

    add_to_user_dict(
      word,
      session.reading,
      session.ac_kana_first_char
    )
    M.dfa.go_to_direct_input_kana_state()
  end)
end

function M.regist_go_back_to_select_kanji_list_state(f)
  M.go_back_to_select_kanji_list_state = f
end

return M

