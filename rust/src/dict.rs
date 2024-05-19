use std::{
  collections::HashMap,
  fs::File,
  io::{self, BufRead, Result},
  path::PathBuf,
};

use encoding_rs::EUC_JP;

pub struct Node {
  children: HashMap<char,Node>,
  kanjis: HashMap<Option<char>, Vec<String>>,
}

pub struct Dict {
  root: Node,
}

impl Node {
  pub fn new() -> Self {
    Self {
      children: HashMap::<char,Node>::new(),
      kanjis: HashMap::<Option<char>, Vec::<String>>::new(),
    }
  }
}

struct ParseResult {
  pub readings: Vec<char>,
  pub kanjis: Vec<String>,
}

impl Dict {
  pub fn new() -> Self {
    Dict { root: Node::new() }
  }
  
  fn is_alphabet(c: &char) -> bool {
    (c >= &'a' && c <= &'z') || (c >= &'A' && c <= &'Z')
  }

  fn parse_line(&self, line: &str) -> Option<ParseResult> {
    if line.starts_with(";;") { // ignore comment
      return None;
    }

    let toks: Vec<&str> = line.split_whitespace().collect();
    if toks.len() != 2 {
      return None;
    }
    
    // parse readings and accompanying kana part
    let mut readings = vec![];

    for c in toks[0].chars() {
      readings.push(c);
    }
    
    // parse kanji part
    let mut kanjis = vec![];

    // toks[1] is surrounded by '/'s
    for tok in toks[1].split('/') {
      if tok.len() > 0 {
        kanjis.push(tok.to_owned()); 
      }
    }

    Some(ParseResult {
      readings,
      kanjis,
    })
  }
  
  pub fn add_dict_file_line(&mut self, line: &str) -> Result<()> {
    match self.parse_line(line) {
      None => Ok(()),
      Some(res) => {
        if res.readings.len() == 0 || res.kanjis.len() == 0 {
          Err(
            io::Error::new(
              io::ErrorKind::NotFound,
              format!("Malformed line: '{}'", line)
            )
          )
        } else {
          let mut node = &mut self.root;

          // get accompanying kana first if exists
          let acc_kana = {
            let last_char = res.readings.last().unwrap();
            if Dict::is_alphabet(last_char) {
              Some(last_char.clone())
            } else {
              None
            }
          };
          
          // add reading nodes exluding the accompanying kana
          let readings = match acc_kana {
            None => &res.readings,
            Some(_) => &res.readings[..res.readings.len() - 1],
          };
          for c in readings {
            if node.children.contains_key(&c) {
              node = node.children.get_mut(&c).unwrap();  
            } else {
              let child_node = Node::new();
              node.children.insert(c.clone(), child_node);
              node = node.children.get_mut(&c).unwrap();
            }
          }

          // add kanjis w/ accompanying kana as the key 
          // to the node of the last reading char
          if !node.kanjis.contains_key(&acc_kana) {
            node.kanjis.insert(acc_kana, vec![]);
          }
          let kanjis = node.kanjis.get_mut(&acc_kana).unwrap();
          for x in res.kanjis {
            kanjis.push(x);
          }
          Ok(())
        }
      }
    }
  }

  pub fn look_up(&self, readings: &Vec<char>, acc_kana: &Option<char>) -> Option<&Vec<String>> {
    let mut node = &self.root;

    for c in readings {
      match node.children.get(c) {
        None => {
          return None;
        },
        Some(x) => {
          node = x;
        },
      };
    }
    node.kanjis.get(acc_kana)
  }
  
  pub fn build(path: &PathBuf) -> io::Result<Dict> {
    if !path.exists() {
      return Err(io::Error::new(
          io::ErrorKind::NotFound,
          format!("{:?} does not exist", path)
      ));
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
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  pub fn test_parse_line() {
    let line = "わるs /碍/";
    let dict = Dict::new(); 

    let maybe_res = dict.parse_line(line);
    match maybe_res {
      None => assert!(false),
      Some(res) => {
        assert_eq!(res.readings.len(), 3); 
        assert_eq!(res.readings[0], 'わ'); 
        assert_eq!(res.readings[1], 'る'); 
        assert_eq!(res.readings[2], 's'); 

        assert_eq!(res.kanjis.len(), 1);
        assert_eq!(res.kanjis[0], "碍");
      },
    }

    let line = "Cyrillic /А/Б/В/Г/Д/Е/Ё/Ж/З/И/Й/К/Л/М/Н/О/П/Р/С/Т/У/Ф/Х/Ц/Ч/Ш/Щ/Ъ/Ы/Ь/Э/Ю/Я/";
    let dict = Dict::new(); 
    let maybe_res = dict.parse_line(line);
    match maybe_res {
      None => assert!(false),
      Some(res) => {
        let act: Vec<String> = res.readings.iter().map(|&c| c.to_string()).collect();
        let exp: Vec<String> = "Cyrillic".chars().map(|c| c.to_string()).collect(); 
        assert_eq!(act, exp);

        let act: Vec<String> = res.kanjis;
        let exp: Vec<String> = "А/Б/В/Г/Д/Е/Ё/Ж/З/И/Й/К/Л/М/Н/О/П/Р/С/Т/У/Ф/Х/Ц/Ч/Ш/Щ/Ъ/Ы/Ь/Э/Ю/Я".split('/').map(|c| c.to_string()).collect(); 
        assert_eq!(act, exp);
      },
    }
  }
  
  #[test]
  pub fn test_looking_up_word_single_some_acc_kana_entry() {
    let line = "わるs /碍/";
    let mut dict = Dict::new(); 
    dict.add_dict_file_line(line).unwrap();

    let readings = vec!['わ', 'る'];
    match dict.look_up(&readings, &Some('s')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "碍");
      },
      None => {
        assert!(false);
      },
    }
    if dict.look_up(&readings, &Some('l')).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec![];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec!['わ'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec!['わ', 'る', 'え'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
  }
  
  #[test]
  pub fn test_looking_up_word_single_noe_acc_kana_entry() {
    let line = "あいて /陵缄/";
    let mut dict = Dict::new(); 
    dict.add_dict_file_line(line).unwrap();
    
    let readings = vec!['あ', 'い', 'て'];
    match dict.look_up(&readings, &None) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "陵缄");
      },
      None => {
        assert!(false);
      },
    }
    if dict.look_up(&readings, &Some('l')).is_some() {
      assert!(false);
    }
    let readings = vec![];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec!['わ'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec!['わ', 'る', 'え'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
  }
  
  #[test]
  pub fn test_looking_up_word_multiple_entries() {
    let lines = vec![
      "あいて /陵缄/",
      "わたs /畔/",
      "わたr /畔/纤/鲜/灸/",
      "わずらw /妊/",
      "わずらu /吹/妊/",
      "わすr /撕/",
      "わざわi /阂/",
      "よわs /煎/",
      "よわr /煎/",
    ];
    let mut dict = Dict::new(); 
    for line in lines {
      dict.add_dict_file_line(line).unwrap();
    }

    // should be able to look up all words
    let readings = vec!['あ', 'い', 'て'];
    match dict.look_up(&readings, &None) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "陵缄");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'た'];
    match dict.look_up(&readings, &Some('s')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "畔");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'た'];
    match dict.look_up(&readings, &Some('r')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 4);
        assert_eq!(kanjis[0], "畔");
        assert_eq!(kanjis[1], "纤");
        assert_eq!(kanjis[2], "鲜");
        assert_eq!(kanjis[3], "灸");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'ず', 'ら'];
    match dict.look_up(&readings, &Some('w')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "妊");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'ず', 'ら'];
    match dict.look_up(&readings, &Some('u')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 2);
        assert_eq!(kanjis[0], "吹");
        assert_eq!(kanjis[1], "妊");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'す'];
    match dict.look_up(&readings, &Some('r')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "撕");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['わ', 'ざ', 'わ'];
    match dict.look_up(&readings, &Some('i')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "阂");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['よ', 'わ'];
    match dict.look_up(&readings, &Some('s')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "煎");
      },
      None => {
        assert!(false);
      },
    }
    let readings = vec!['よ', 'わ'];
    match dict.look_up(&readings, &Some('r')) {
      Some(kanjis) => {
        assert_eq!(kanjis.len(), 1);
        assert_eq!(kanjis[0], "煎");
      },
      None => {
        assert!(false);
      },
    }

    // should not able to look up words not in the tree
    let readings = vec!['あ', 'い', 'て'];
    if dict.look_up(&readings, &Some('a')).is_some() {
      assert!(false);
    }
      
    let readings = vec!['わ', 'た'];
    if dict.look_up(&readings, &Some('a')).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    let readings = vec!['わ', 'ず', 'ら'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &Some('i')).is_some() {
      assert!(false);
    }
    let readings = vec!['わ', 'す'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &Some('i')).is_some() {
      assert!(false);
    }
    let readings = vec!['わ', 'ざ', 'わ'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &Some('w')).is_some() {
      assert!(false);
    }
    let readings = vec!['よ', 'わ'];
    if dict.look_up(&readings, &None).is_some() {
      assert!(false);
    }
    if dict.look_up(&readings, &Some('w')).is_some() {
      assert!(false);
    }
  }

  #[ignore]
  #[test]
  pub fn trest_build() {
    let home = dirs::home_dir().expect("Failed to get the home dir");
    let dict_file = home.join(".skk").join("SKK-JISYO.S");

    let start = std::time::Instant::now();
    Dict::build(&dict_file).unwrap();
    let duration = start.elapsed();

    println!("Took {} ms", duration.as_millis());
  }
}

