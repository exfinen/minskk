use crate::dict::Dict;

use libc::{c_char, size_t};
use once_cell::sync::{Lazy, OnceCell};
use std::{
  ffi::CStr,
  path::PathBuf,
  ptr,
  slice,
  str::FromStr,
  sync::Mutex,
  thread,
};

static DICT: OnceCell<Mutex<Dict>> = OnceCell::new();
static RESULT_CACHE: Lazy<Mutex<Vec<String>>> =
  Lazy::new(|| Mutex::new(vec![]));

#[no_mangle]
pub extern "C" fn build(
  dict_file_path: *const c_char,
) {
  let dict_file_path = unsafe {
    CStr::from_ptr(dict_file_path).to_str().unwrap()
  }.to_string();
  
  match PathBuf::from_str(&dict_file_path) {
    Ok(dict_file_path) => {
      // build dictionary on a background thread
      thread::spawn(move || {
        match Dict::build(&dict_file_path) {
          Ok(dict) => {
            DICT.set(Mutex::<Dict>::new(dict)).unwrap();
          },
          Err(e) => println!("Failed to build dictionary w/ {:?}: {:?}", dict_file_path, e),
        }
      });
    },
    Err(e) => {
      eprintln!("Malformed path {:?}: {:?}", dict_file_path, e);
    },
  }
}

#[no_mangle]
pub extern "C" fn look_up(
  chars: *mut *mut c_char,
  ac_kana: c_char,
  num_chars: size_t,
) {
  let strings_slice = unsafe {
    std::slice::from_raw_parts(chars, num_chars)
  };

  let mut reading = vec![];
  for &c_str_ptr in strings_slice.iter() {
    let c_str = unsafe {
      std::ffi::CStr::from_ptr(c_str_ptr)
    };
    match c_str.to_str() {
      Ok(s) => {
        for c in s.chars() {
          reading.push(c);
        }
      },
      Err(e) => panic!("Failed to convert to Rust string: {e}"),
    }
  }
  RESULT_CACHE.lock().unwrap().clear();

  match &DICT.get() {
    Some(dict) => {
      let dict = dict.lock().unwrap();
      let ac_kana = {
        let ac_kana = ac_kana as u8 as char;
        if ac_kana  == ' ' {
          None
        } else {
          Some(ac_kana)
        }
      };
      if let Some(res) = dict.look_up(&reading, &ac_kana) {
        for s in res {
          RESULT_CACHE.lock().unwrap().push(s.to_string());
        }
      }
    },
    None => (),
  };
}

#[no_mangle]
// results: pointer to byte buffers. each buffer is expected to be large enough to hold a result
// buf_size: size of the byte buffer
// offset: start index of the results to return
// num_results: [in] maximum # of results [out] # of returned results
pub extern "C" fn get_results(
  results: *mut *mut c_char,
  buf_size: size_t,
  offset: size_t,
  num_results: *mut size_t,
) {
  let result_cache = &RESULT_CACHE.lock().unwrap();
  let safe_num_results = unsafe { *num_results };
  let from = offset;
  let to = usize::min(offset + safe_num_results, result_cache.len());
  
  let results = unsafe {
    slice::from_raw_parts_mut(results, safe_num_results)
  };

  let mut i: size_t = 0;

  for result in result_cache[from..to].iter() {
    let dest = results[i];
    unsafe {
      let src = result.as_ptr() as *const c_char;
      // -1 for null-termination space
      let len = usize::min(result.len(), buf_size - 1);

      ptr::copy(src, dest, len);
      *dest.add(len) = 0; // null-terminate
    }

    i += 1;
    if i == safe_num_results {
      break;
    }
  }

  // return the number of copied results to the caller
  unsafe { *num_results = i };
}

