# minskk

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is mostly not configurable and works out of the box with a sticky shift setting.

**Status:** **Work in Progress**

Due to the architecture of [DM250](https://www.kingjim.co.jp/pomera/dm250/) (`armv7`) where `v8` cannot be easily built, existing SKK plugins based on `Deno` that depends on `v8` don't work on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

This plugin is written fully from scratch using `Lua` and `Rust` and works on an environment where `Rust` and `Neovim` can run including `Debian 11` on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

## Currently Supported
- Hiragana
- Katakana
- Half-width (hankaku) Alphanumeric Characters
- Full-width (zenkaku) Alphabets
- Kanji Conversion (with many issues)

## Known Issues
- Lines disappear and cannot undo
- Many UI edge cases still not addressed

## TO BE SUPPORTED
- Back Space in Input Reading State
- Full-width (zenkaku) Symbols
- Local Dictionary
- Word Completion
- Annotation
- Candidate Selection Dialog

## Requirements
- macOS (Linux will be supported)
- [rustup](https://rustup.rs/)
- [SKK-JISHO.L](http://openlab.jp/skk/dic/SKK-JISYO.L.gz) under `~/.skk`

## Installation
Currently only manual installation is avaialble.

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

