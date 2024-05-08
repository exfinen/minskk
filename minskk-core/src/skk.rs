use libc::{c_char, size_t};
use std::slice;

#[no_mangle]
pub extern "C" fn get_kanji(buf: *const c_char, buf_size: size_t) -> size_t {
  let fixed_kanji = "漢字です";
  let kanji_bytes = fixed_kanji.as_bytes();
  let required_size = kanji_bytes.len();

  if buf.is_null() || buf_size < required_size {
    return required_size as size_t;
  }

  unsafe {
    let buf_slice = slice::from_raw_parts_mut(buf as *mut u8, buf_size);
    buf_slice[..required_size].copy_from_slice(kanji_bytes);
  }

  required_size as size_t
}

#[cfg(test)]
mod tests {
  #[test]
  pub fn test_test() {
    
  }
}

