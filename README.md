# minskk

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

**Status:** **Work in Progress**

Due to the architecture of [DM250](https://www.kingjim.co.jp/pomera/dm250/) (`armv7`) where `v8` cannot be easily built, existing SKK plugins based on `Deno` that depends on `v8` such as [skkeleton](https://github.com/vim-skk/skkeleton) don't work on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

This plugin is written fully from scratch using `Lua` as glue code and `Rust` for the rest, and therefore should work on any environment where `Rust` and `Neovim` can run including `Debian 11` on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

## Currently, you can more or less type in:
- Hiragana
- Katakana
- Half-width (hankaku) Alphabets

## TO BE SUPPORTED
- Half-width (hankaku) Symbols
- Full-width (zenkaku) Alphanumeric Characters
- Kanji

