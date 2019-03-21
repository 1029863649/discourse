RSpec::Matchers.define :be_within_one_second_of do |expected_time|
  match { |actual_time| (actual_time - expected_time).abs < 1 }
  failure_message do |actual_time|
    "#{actual_time} is not within 1 second of #{expected_time}"
  end
end
