# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Changed

- Only send info log after processing a group of events

### Removed
  - Remove `processes_events` and `projects_events` as these have been [removed
  in event_sourcery](https://github.com/envato/event_sourcery/pull/161).

## [0.5.0] - 2017-7-27
- First Version of YARD documentation.
- Fix Sequel deprecation by globally loading pg extensions

## [0.4.0] - 2017-6-21
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

## [0.3.0] - 2017-6-16
### Changed
- The event store persists the event `correlation_id` and `causation_id`.
  To facilitate this `correlation_id` and `causation_id` columns have been
  added to the `events` table and the `write_events` function has been
  altered. Event Sourcery apps will need to ensure these DB changes have
  been applied to use this version of Event Sourcery.
- The emit_events method now accepts typed events instead of symbols
- Remove dynamic emit events methods from reactors (e.g. emit_item_added)

## [0.2.0] - 2017-6-1
### Changed
- Make `EventSourcery::Postgres::OptimisedEventPollWaiter#shutdown` private
- Updated `EventSourcery::Postgres::OptimisedEventPollWaiter#poll` to ensure that `#shutdown!` is run when an error is raised
or when the loop stops

### Added
- Configure projector tracker table name via `EventSourcery::Postgres.configure`

## [0.1.0] - 2017-5-26
### Changed
- Imported code from the [event_sourcery](https://github.com/envato/event_sourcery).
- Postgres related configuration is through `EventSourcery::Postgres.configure`
  instead of `EventSourcery.configure`.
