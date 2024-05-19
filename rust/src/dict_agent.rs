use crate::dict::Dict;

use libc::{c_char, size_t};
use once_cell::sync::Lazy;
use std::sync::Mutex;
use std::slice;
use std::ptr;

static _DICT: Lazy<Dict> = Lazy::new(|| {
  let home = dirs::home_dir().expect("Failed to get the home dir");
  let dict_file = home.join(".skk").join("SKK-JISYO.S");
  Dict::build(&dict_file).expect("Error: Failed to load a dictionary")
});

static RESULT_CACHE: Lazy<Mutex<Vec<String>>> = Lazy::new(|| Mutex::new(vec![]));

#[no_mangle]
pub extern "C" fn look_up(
  chars: *mut *mut c_char,
  num_chars: size_t
) {
  let strings_slice = unsafe {
    assert!(!chars.is_null(), "chars argument is null");
    std::slice::from_raw_parts(chars, num_chars)
  };

  for &c_str_ptr in strings_slice.iter() {
    let c_str = unsafe {
      assert!(!c_str_ptr.is_null(), "string pointer is null");
      std::ffi::CStr::from_ptr(c_str_ptr)
    };
    match c_str.to_str() {
      Ok(_) => (),
      Err(e) => eprintln!("Failed to convert C string to Rust string: {e}"),
    }
  }

  let res = vec![
    "候補１",
    "候補２",
    "候補３",
    "候補４",
    "候補５",
  ];
  RESULT_CACHE.lock().unwrap().clear();
  for s in res {
    RESULT_CACHE.lock().unwrap().push(s.to_string());
  }
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


