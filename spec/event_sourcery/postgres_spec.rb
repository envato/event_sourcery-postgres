require "spec_helper"

RSpec.describe EventSourcery::Postgres do
  it "has a version number" do
    expect(EventSourcery::Postgres::VERSION).not_to be nil
  end
end
