# minskk

**Status:** **Work in Progress**

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is mostly non-configurable and works out of the box with a sticky-shift setting.

This plugin is written using `Rust` for the dictionary related part and `Lua` for the rest, and works on an environment where `Rust` is available including `Debian 11` on DM250.

## Implemented
- Hiragana entry
- Katakana entry
- Half-width (hankaku) Alphanumeric Character entry
- Full-width (zenkaku) Alphabet entry
- Kanji Conversion (wip)
- Gzipped dictionary support
- De/Serialization w/ gzip of once loaded library

## Known issues
- Lines disappear and cannot undo

## TO DO
- Loading dictionary directly from gz
- de/ser loaded dictionary from/to a file
- Full-width (zenkaku) Symbol entry
- Local Dictionary
- Word Completion
- Annotation
- Candidate Selection Dialog
- C-g
- Plugin manager support (vimplug at least)

## Requirements
- macOS or Linux
- [rustup](https://rustup.rs/)

## Installation
Currently this plugin has to be installed manually as follows.

```bash
$ cd ~/.config/nvim/pack/plugins/start
$ git clone https://github.com/exfinen/minskk.git
$ cd rust
$ cargo build
```

Also the plugin expects [SKK-JISHO.L](http://openlab.jp/skk/dic/SKK-JISYO.L.gz) to exist under `~/.skk`. This can be overridden using `minskk_override` explained below.

## Configuration
1. `minskk_statusline` is exposed to provide the current state of the plugin outside. e.g. the following adds the minskk state to the status line.

   ```vim
   set statusline+=%{v:lua.minskk_statusline()}
   ```

2. use `minskk_override` global variable to override the default settings. e.g. 

   ```vim
   lua << EOF
     vim.g.minskk_override = {
       dict_file_path = '~/.skk/SKK-JISYO.S',
     }
   EOF
   ```

## Note on using the plugin on DM250
- It takes a relatively long time to load `SKK-JISHO.L` on DM250. Although the plugin works fine in terms of speed once the dictionary is loaded, using `SKK-JISHO.S` is recommended.
