# minskk

Minimalist Neovim plugin SKK implementation aiming to be functional on [DM250](https://www.kingjim.co.jp/pomera/dm250/).

Being minimalist, the plugin is non-configurable and works out of the box with a sticky shift setting.

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
- Conflicts with Telescope
- Many edge cases still not yet covered

## TO BE SUPPORTED
- Full-width (zenkaku) Symbols
- Local Dictionary
- Word Completion
