local M = {
  file_path = 'skk-dict',
  lines = {},
}

function M.init(dfa, util, file_path)
  M.dfa = dfa
  M.util = util

  local ffi_file_path = M.util.ffi.new('char[?]', #file_path + 1)
  M.util.ffi.copy(ffi_file_path, file_path, #file_path)

  local res = M.util.dict.load_or_create_user_dict(ffi_file_path)
  if res then
    M.file_path = file_path
  else
    error('Failed to load or create user dict file ' .. file_path)
  end
end

function M.add_word(
  reading, ac_kana_first_char, word
)
  local ffi = M.util.ffi

  -- +1 for null terminator
  local ffi_reading = ffi.new('char[?]', #reading + 1)
  ffi.copy(ffi_reading, reading, #reading)

  local ffi_ac_kana = ffi.new("char[1]", ac_kana_first_char:byte())

  -- +1 for null terminator
  local ffi_word = ffi.new('char[?]', #word + 1)
  ffi.copy(ffi_word, word, #word)

  M.util.dict.add_word(ffi_reading, ffi_ac_kana, ffi_word)
end

function M.save()
  M.util.dict.save_user_dict()
end

return M
