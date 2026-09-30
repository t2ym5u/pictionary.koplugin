# Changelog

All notable changes to this project will be documented in this file.

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
