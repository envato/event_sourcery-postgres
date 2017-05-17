# EventSourcery::Postgres

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'event_sourcery-postgres'
```

## Configure

```
EventSourcery::Postgres.configure do |config|
  config.event_store_database = Sequel.connect(...)
  config.projections_database = Sequel.connect(...)
  config.use_optimistic_concurrency = true
  config.write_events_function_name = 'writeEvents'
  config.events_table_name = :events
  config.aggregates_table_name = :aggregates
  config.callback_interval_if_no_new_events = 60
end
```

## Usage


### Event Store

```
ItemAdded = EventSourcery::Event

EventSourcery::Postgres.event_store.sink(ItemAdded.new(aggregate_id: uuid, body: { }}))
EventSourcery::Postgres.event_store.get_next_from(0).each do |event|
  puts event.inspect
end
```

### Projectors & Reactors

```
class ItemProjector
  include EventSourcery::Postgres::Projector

  table :items do
    column :item_uuid, 'UUID NOT NULL'
    column :title, 'VARCHAR(255) NOT NULL'
  end

  project ItemAdded do |event|
    table(:items).insert(item_uuid: event.aggregate_id,
                         title: event.body.fetch('title'))
  end
end

class UserEmailer
  include EventSourcery::Postgres::Reactor

  emits_events SignUpEmailSent

  process UserSignedUp do |event|
    emit_event SignUpEmailSent.new(user_id: event.aggregate_id) do
      UserMailer.signed_up(...).deliver
    end
  end
end

EventSourcery::EventProcessing::ESPRunner.new(
  event_processors: [item_projector, user_emailer],
  event_store:      EventSourcery::Postgres.config.event_store,
  stop_on_failure:  true,
).start!
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/envato/event_sourcery-postgres.
