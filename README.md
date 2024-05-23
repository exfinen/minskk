# minskk

**Status:** **Work in Progress**

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is mostly non-configurable and works out of the box with a sticky-shift setting.

This plugin is written using `Rust` for the dictionary related part and `Lua` for the rest, and works on an environment where `Rust` is available including `Debian 11` on DM250.

## Implemented
- Hiragana entry
- Katakana entry
- Half-width (hankaku) alphanumeric character entry
- Full-width (zenkaku) alphabet entry
- Kanji conversion (with remaining issues)
- Gzipped dictionary support
- De/serialization w/ gzip of once-loaded dictionary

## Known issues

## TO DO
- Full-width (zenkaku) symbol entry
- Multiple dictionary support
- Word registration
- Word completion
- Annotation
- Candidate selection dialog
- C-g
- Plugin manager support (vimplug at least)

## Requirements
- macOS or Linux
- [rustup](https://rustup.rs/)

## Installation
Currently this plugin has to be installed manually as follows.

```bash
$ mkdir -p ~/.config/nvim/pack/plugins/start
$ cd ~/.config/nvim/pack/plugins/start
$ git clone https://github.com/exfinen/minskk.git
$ cd rust
$ cargo build --release
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

## Note on DM250
This plugin serializes and gzips a dictionary the first time it is loaded. 
From the second time onward, the plugin loads the dictionary from the serialized file.

Below is a measurement of dicitonary load time for each dictionary type and file category.

|                        | SKK-JISYO.S | SKK-JISHO.M | SKK-JISYO.L |
| ---------------------- | ----------- | ----------- | ----------- |
| Not compressed         |      201 ms |      503 ms |   12,102 ms |
| Gzipped                |      186 ms |      484 ms |   11,152 ms |
| Serialize-and-gzipped  |       39 ms |       97 ms |    2,304 ms |

