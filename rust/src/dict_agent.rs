use crate::dict::Dict;

use flate2::read::GzDecoder;
use libc::{c_char, size_t};
use once_cell::sync::{Lazy, OnceCell};
use std::{
  ffi::CStr,
  fs::{self, File},
  io::{BufReader, Read},
  path::{Path, PathBuf},
  ptr,
  slice,
  str::FromStr,
  sync::Mutex,
  thread,
  time::Instant,
};

static DICT: OnceCell<Mutex<Dict>> = OnceCell::new();
static RESULT_CACHE: Lazy<Mutex<Vec<String>>> =
  Lazy::new(|| Mutex::new(vec![]));

pub enum DictFile {
  Gz(PathBuf, PathBuf),
  SerGz(PathBuf),
  Raw(PathBuf, PathBuf),
  NotFound,
}

#[repr(C)]
pub enum BuildResult {
  Success = 0,
  FileNotFound = 1,
  PathMalformed= 2,
}

fn read_lines_and_set_dict<T: Read>(reader: &mut BufReader<T>) {
  let lines = Dict::reader_to_lines(reader);
  match Dict::build(&lines) {
    Ok(dict) => DICT.set(Mutex::<Dict>::new(dict)).unwrap(),
    Err(e) => {
      println!("Failed to build dictionary: {:?}", e);
    },
  }
}

fn get_path_ser_gz(
  dir: &Option<&Path>,
  file_name: &String,
) -> PathBuf {
  match dir {
    Some(dir) => dir.join(file_name.clone() + ".ser.gz"),
    None => { PathBuf::from(file_name.clone() + ".ser.gz") },
  }
}

fn get_path_gz(
  dir: &Option<&Path>,
  file_name: &String,
) -> PathBuf {
  match dir {
    Some(dir) => dir.join(file_name.clone() + ".gz"),
    None => { PathBuf::from(file_name.clone() + ".gz") },
  }
}

fn exists_as_file(path: &PathBuf) -> bool {
  path.exists() && fs::metadata(&path).unwrap().is_file()
}

fn drop_gz_suffix_if_exists(s: String) -> String {
  if s.ends_with(".gz") {
    let end = s.len() - ".gz".len();
    s[..end].to_string()
  } else { s }
}

// load precedence:
// 1. ser.gz
// 2. gz
// 3. others
fn get_dict_file_to_load(base_path: &PathBuf) -> DictFile {
  match &base_path.file_name() {
    None => DictFile::NotFound,
    Some(file_name) => {
      let file_name = drop_gz_suffix_if_exists(
        file_name.to_str().unwrap().to_string()
      );
      let dir = base_path.parent();

      // if ser.gz exist, should load it
      let path_ser_gz = get_path_ser_gz(&dir, &file_name); 
      if exists_as_file(&path_ser_gz) {
        DictFile::SerGz(path_ser_gz)

      } else {
        // otherwise, should load .gz if exists
        let path_gz = get_path_gz(&dir, &file_name);
        if exists_as_file(&path_gz) {
          DictFile::Gz(path_gz, path_ser_gz)

        } else {
          // if both don't exist, base_path can be a raw file
          if exists_as_file(base_path) {
            DictFile::Raw(base_path.clone(), path_ser_gz)

          } else {
            DictFile::NotFound
          }
        }
      }
    }
  }
}

fn gen_ser_gz(path_ser_gz: &PathBuf) {
  match &DICT.get() {
    Some(dict) => {
      let dict = dict.lock().unwrap();
      if let Err(e) = dict.serialize_to_file(&path_ser_gz) {
        println!("{:?}", e);
      }
    },
    None => println!("should not be visited. check code (dict-agent 2)"),
  };
}

#[no_mangle]
pub extern "C" fn build_from_file(dict_file: &DictFile) {
  match dict_file {
    DictFile::SerGz(path_ser_gz) => {
      match Dict::deserialize_from_file(&path_ser_gz) {
        Ok(dict) => {
          DICT.set(Mutex::<Dict>::new(dict)).unwrap();
        },  
        Err(e) => {
          println!("{:?}", e);
        },
      }
    },
    DictFile::Gz(path_gz, path_ser_gz) => {
      let file = File::open(&path_gz).unwrap();
      let file = GzDecoder::new(file);
      let mut reader = BufReader::new(file);
      read_lines_and_set_dict(&mut reader);
      gen_ser_gz(&path_ser_gz);
    },
    DictFile::Raw(path_raw, path_ser_gz) => {
      let file = File::open(&path_raw).unwrap();
      let mut reader = BufReader::new(file);
      read_lines_and_set_dict(&mut reader);
      gen_ser_gz(&path_ser_gz);
    },
    DictFile::NotFound => {
      println!("should not be visited. check code (dict_agent 1)");
    }
  }
}

#[no_mangle]
pub extern "C" fn build(
  base_dict_file_path: *const c_char,
) -> BuildResult {
  let base_dict_file_path = unsafe {
    CStr::from_ptr(base_dict_file_path).to_str().unwrap()
  }.to_string();

  let base_dict_file_path =
    shellexpand::tilde(&base_dict_file_path);
  
  match PathBuf::from_str(&base_dict_file_path) {
    Ok(base_dict_file_path) => {
      match get_dict_file_to_load(&base_dict_file_path) {
        DictFile::NotFound => {
          BuildResult::FileNotFound
        },
        dict_file => {
          thread::spawn(move || {
            let start = Instant::now();
            build_from_file(&dict_file);
            let duration = start.elapsed();
            println!("Loaded dict in {} ms", duration.as_millis()); 
          });
          BuildResult::Success
        },
      }
    },
    Err(_) => {
      BuildResult::PathMalformed
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

