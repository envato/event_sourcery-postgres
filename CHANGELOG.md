# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- Added index on the `events` table for `correlation_id` and `causation_id`
  columns.

## [0.3.0] - 2017-6-16
### Changed
- The event store persists the event `correlation_id` and `causation_id`.
  To facilitate this `correlation_id` and `causation_id` columns have been
  added to the `events` table and the `write_events` function has been
  altered. Event Sourcery apps will need to ensure these DB changes have
  been applied to use this version of Event Sourcery.
- Reactors store the UUID of the event being processed in the `causation_id`
  of any emitted events. This replaces the old behaviour of storing id of the
  event being processed in a `_driven_by_event_id` attribute in the emitted
  event's body.

## [0.2.0] - 2017-6-1
### Changed
- Make `EventSourcery::Postgres::OptimisedEventPollWaiter#shutdown` private
- Updated `EventSourcery::Postgres::OptimisedEventPollWaiter#poll` to ensure that `#shutdown!` is run when an error is raised
or when the loop stops
- Remove dynamic emit events methods from reactors (e.g. emit_item_added)
- The emit_events method now accepts typed events instead of symbols

### Added
- Configure projector tracker table name via `EventSourcery::Postgres.configure`

## [0.1.0] - 2017-5-26
### Changed
- Imported code from the [event_sourcery](https://github.com/envato/event_sourcery).
- Postgres related configuration is through `EventSourcery::Postgres.configure`
  instead of `EventSourcery.configure`.
