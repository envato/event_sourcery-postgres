# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added
- Configure projector tracker table name via `EventSourcery::Postgres.configure`

## [0.1.0] - 2017-5-26

### Changed
- Imported code from the [event_sourcery](https://github.com/envato/event_sourcery).
- Postgres related configuration is through `EventSourcery::Postgres.configure`
  instead of `EventSourcery.configure`.
