# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added

- Test against Ruby 3.0 in the CI build ([#67]).

### Changed

- Use GitHub Actions for the CI build instead of Travis CI ([#66]).
- This project now uses `main` as its default branch ([#68]).
  - Documentation updated to refer to `main` and links updated accordingly.

[#66]: https://github.com/envato/event_sourcery-postgres/pull/66
[#67]: https://github.com/envato/event_sourcery-postgres/pull/67
[#68]: https://github.com/envato/event_sourcery-postgres/pull/68

### Changed


## [0.8.1] - 2020-10-02
### Added
- Add Ruby 2.6 and 2.7 to the CI test matrix.

### Removed
- Remove Ruby 2.2 from the CI test matrix.
- Support for Boxen.

### Fixed
- Upgrade development dependency Rake to version 13. This resolves
  [CVE-2020-8130](https://github.com/advisories/GHSA-jppv-gw3r-w3q8).

- Resolve warnings raised when running on Ruby 2.7.

## [0.8.0] - 2018-08-06
### Added
- Add a `on_events_recorded` config option, that defaults to a no-op proc, \
  to handle any app specific logic after the events are recoded on `EventStore#sink`

## [0.7.0] - 2018-05-23
### Added
- Add a `projector_transaction_size` config option to control how many events
  are processed before the transaction is commited. The default value is 1 to
  match the existing behavour.

  We suggest setting this to match the number of events returned from the event
  store subscription. This is [now configurable](https://github.com/envato/event_sourcery/pull/197)
  in event_sourcery by configuring `subscription_batch_size`.

### Removed
- Remove upper bound version restriction on `sequel` gem. Now accepts versions
  5 and higher.

## [0.6.0] - 2018-01-02
### Changed

- Only send info log after processing a group of events

### Removed
  - Remove `processes_events` and `projects_events` as these have been [removed
  in event_sourcery](https://github.com/envato/event_sourcery/pull/161).

## [0.5.0] - 2017-07-27
- First Version of YARD documentation.
- Fix Sequel deprecation by globally loading pg extensions

## [0.4.0] - 2017-06-21
### Changed
- Reactors store the UUID of the event being processed in the `causation_id`
  of any emitted events. This replaces the old behaviour of storing id of the
  event being processed in a `_driven_by_event_id` attribute in the emitted
  event's body.

### Added
- Reactors store the correlation id of the event being processed in the
  `correlation_id` of any emitted events.
- Added index on the `events` table for `correlation_id` and `causation_id`
  columns.

## [0.3.0] - 2017-06-16
### Changed
- The event store persists the event `correlation_id` and `causation_id`.
  To facilitate this `correlation_id` and `causation_id` columns have been
  added to the `events` table and the `write_events` function has been
  altered. Event Sourcery apps will need to ensure these DB changes have
  been applied to use this version of Event Sourcery.
- The emit_events method now accepts typed events instead of symbols
- Remove dynamic emit events methods from reactors (e.g. emit_item_added)

## [0.2.0] - 2017-06-01
### Changed
- Make `EventSourcery::Postgres::OptimisedEventPollWaiter#shutdown` private
- Updated `EventSourcery::Postgres::OptimisedEventPollWaiter#poll` to ensure that `#shutdown!` is run when an error is raised
or when the loop stops

### Added
- Configure projector tracker table name via `EventSourcery::Postgres.configure`

## 0.1.0 - 2017-05-26
### Changed
- Imported code from the [event_sourcery](https://github.com/envato/event_sourcery).
- Postgres related configuration is through `EventSourcery::Postgres.configure`
  instead of `EventSourcery.configure`.

[Unreleased]: https://github.com/envato/event_sourcery-postgres/compare/v0.8.1...HEAD
[0.8.1]: https://github.com/envato/event_sourcery-postgres/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/envato/event_sourcery-postgres/compare/v0.1.0...v0.2.0
