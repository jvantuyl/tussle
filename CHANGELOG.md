# Changelog

## v0.2.0

Fork of the original [`tus`](https://hex.pm/packages/tus) package, renamed to Tussle.

### Changes from original tus package

- Renamed package from `tus` to `tussle` to allow publishing updates to Hex
- Updated to Elixir 1.18+ / OTP 28
- Replaced deprecated `use Mix.Config` with `import Config`
- Replaced deprecated `Supervisor.Spec.worker/3` with modern child spec syntax
- Added `Tussle.Storage` behaviour module (from ringods)
- Added `@type t()` typespec to `Tussle.File` (from ringods)
- Fixed metadata parsing to return map instead of list (from ringods)
- Added `@behaviour Tussle.Storage` to `Tussle.Storage.Local`

### Merged community contributions

- Storage behaviour and File typespecs (ringods via bucha)
- Metadata as map fix (ringods via bucha)
- Expiration protocol (davec82)
- on_complete_upload result checking (davec82)
- Empty metadata handling (davec82)
- Location prefix support (zkessin)
- Storage provider offset control (Clause-Logic)
- init_file callback (marcinkoziej)
- Missing config handling (marcinkoziej)
- source_url fix (feng19)
- mix.exs formatting fix (joeljuca)
