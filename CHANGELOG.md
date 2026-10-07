# Changelog

All notable changes to this project will be documented in this file.

## [1.1.15] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.
- `i18n_fr.lua` shipped to the device but was never loaded: nothing called
  `i18n.extend()` on it, so the whole table was dead weight. main.lua now
  merges it in before the menu entry is built.


## [1.1.14] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.1.13] - 2026-09-30

### Added
- A spec over the word list: every category has an id, a name and all three
  difficulty buckets, no bucket is empty, every entry is a non-empty string
  without stray whitespace, and ids are unique. A missing bucket used to
  surface only when a team drew that category mid-round.
- The duplicate check is per-category on purpose: categories overlap by
  design -- "Shark" belongs to both ocean and animals -- so only a word
  repeated inside one category is a defect. There are none.

## [1.1.8] - 2026-07-29

### Changed
- Word picking draws uniformly at random with no repeat-avoidance, so
  the old bank of exactly 10 words per category/difficulty tier meant a
  repeat was likely within just a few rounds. Each category (French and
  English) now carries roughly 40 words per easy/medium/hard tier
  instead of 10.

### Added
- 16 new categories per language — transport, human body, clothing,
  music, technology, space, fantasy, movies and TV, celebrations,
  school, house, toys, ocean, weather, tools, and birds — bringing each
  language from 8 categories to 24.
