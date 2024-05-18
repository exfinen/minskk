use crate::dict::Dict;

use std::{
  fs::File,
  io::{self, BufRead},
  path::PathBuf,
};
use std::slice;

use encoding_rs::EUC_JP;
use libc::{c_char, size_t};

pub fn build_dict(path: &PathBuf) -> io::Result<Dict> {
  if !path.exists() {
      return Err(io::Error::new(io::ErrorKind::NotFound, format!("{:?} does not exist", path)));
  }

  let file = File::open(&path)?;
  let mut reader = io::BufReader::new(file);
  let mut dict = Dict::new();

  while {
    let mut buf = Vec::<u8>::new();
    if reader.read_until(0x0a as u8, &mut buf)? == 0 {
      false
    } else {
      let res = EUC_JP.decode(&buf);
      let line = res.0.trim_end_matches("\n");
      dict.add_dict_file_line(line)?;
      true
    }
  } {}

  Ok(dict)
}

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
  use super::*;
  use std::time::Instant;

  #[test]
  pub fn build_dict_test() {
    let home = dirs::home_dir().expect("Failed to get the home dir");
    let dict_file = home.join(".skk").join("SKK-JISYO.S");

    let start = Instant::now();
    build_dict(&dict_file).unwrap();
    let duration = start.elapsed();

    println!("Took {} ms", duration.as_millis());
  }
}

