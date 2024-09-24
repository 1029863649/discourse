# frozen_string_literal: true

module AutomationSpecHelpers
  def capture_contexts(&blk)
    DiscourseAutomation::CapturedContext.capture(&blk)
  end
end

module DiscourseAutomation::CapturedContext
  def self.add(context)
    @contexts << context if @capturing
  end

  def self.capture
    raise StandardError, "Nested capture is not supported" if @capturing
    raise StandardError, "Expecting a block" if !block_given?
    @capturing = true
    @contexts = []
    yield
    @contexts
  ensure
    @capturing = false
  end
end

DiscourseAutomation::Scriptable.add("something_about_us") do
  script do |context|
    DiscourseAutomation::CapturedContext.add(context)
    nil
  end
  triggerables [DiscourseAutomation::Triggers::API_CALL]
end

DiscourseAutomation::Scriptable.add("nothing_about_us") do
  triggerables [DiscourseAutomation::Triggers::API_CALL]
end

RSpec.configure do |config|
  config.include AutomationSpecHelpers

  config.before(:suite) do
    if defined?(migrate_column_to_bigint)
      migrate_column_to_bigint(DiscourseAutomation::Field, :automation_id)
      migrate_column_to_bigint(DiscourseAutomation::PendingAutomation, :automation_id)
      migrate_column_to_bigint(DiscourseAutomation::PendingPm, :automation_id)
    end
  end
end
