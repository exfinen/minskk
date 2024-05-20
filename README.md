# minskk

**Status:** **Work in Progress**

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is mostly non-configurable and works out of the box with a sticky-shift setting.

This plugin is written fully from scratch using mostly in `Lua` and in `Rust` for the dictionary related part, and should work on an environment where `Rust` is available run including `Debian 11` on DM250.

## Implemented
- Hiragana entry
- Katakana entry
- Half-width (hankaku) Alphanumeric Character entry
- Full-width (zenkaku) Alphabet entry
- Kanji Conversion (with remaining issues)

## Known Issues
- Lines disappear and cannot undo

## TO BE IMPLEMENTED
- Full-width (zenkaku) Symbol entry
- Local Dictionary
- Word Completion
- Annotation
- Candidate Selection Dialog
- C-g
- Plugin manager support (at least vimplug)

## Requirements
- macOS (Linux will be supported)
- [rustup](https://rustup.rs/)
- [SKK-JISHO.L](http://openlab.jp/skk/dic/SKK-JISYO.L.gz) under `~/.skk`

## Installation
Currently this plugin has be installed manually as follows.

```bash
$ cd ~/.config/nvim/pack/plugins/start
$ git clone https://github.com/exfinen/minskk.git
$ cd rust
$ cargo build
```

## Configuration
1. `minskk_statusline` is exposed to get the current state the plugin is in. e.g. the following adds the minskk state to the status line.

   ```vim
   set statusline+=%{v:lua.minskk_statusline()}
   ```

