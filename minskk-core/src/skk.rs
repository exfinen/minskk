use libc::size_t;

#[no_mangle]
pub extern "C" fn test() -> size_t {
  42
}

#[cfg(test)]
mod tests {
  #[test]
  pub fn test_test() {
    
  }
}

