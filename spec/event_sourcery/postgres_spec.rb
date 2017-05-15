require "spec_helper"

RSpec.describe EventSourcery::Postgres do
  it "has a version number" do
    expect(EventSourcery::Postgres::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
