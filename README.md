# minskk

**Status:** **Work in Progress**

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is mostly non-configurable and works out of the box with a sticky-shift setting.

This plugin is written fully from scratch using `Rust` for the dictionary related part and `Lua` for the rest, and works on an environment where `Rust` is available including `Debian 11` on DM250.

## Implemented
- Hiragana entry
- Katakana entry
- Half-width (hankaku) Alphanumeric Character entry
- Full-width (zenkaku) Alphabet entry
- Kanji Conversion (with remaining issues)

## Known Issues
- Lines disappear and cannot undo
- neovim quietly dies upon rust panic

## TO BE IMPLEMENTED
- Allowing to use and load a dictionary at the same time
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
- [SKK-JISHO.L](http://openlab.jp/skk/dic/SKK-JISYO.L.gz) under `~/.skk`

## Installation
Currently this plugin has to be installed manually as follows.

```bash
$ cd ~/.config/nvim/pack/plugins/start
$ git clone https://github.com/exfinen/minskk.git
$ cd rust
$ cargo build
```

## Configuration
1. `minskk_statusline` is exposed to provide the current state of the plugin. e.g. the following adds the minskk state to the status line.

   ```vim
   set statusline+=%{v:lua.minskk_statusline()}
   ```

## Note on Using the Plugin on DM250
- It takes a relatively long time to load `SKK-JISHO.L`. Although the plugin works fine in terms of speed once the dictionary is loaded, you may want to consider using a smaller dictionary if the dictionary loading time is an issue.
