# frozen_string_literal: true

require 'rails_helper'

describe ::Jobs::Base do
  class GoodJob < ::Jobs::Base
    attr_accessor :count
    def execute(args)
      self.count ||= 0
      self.count += 1
    end
  end

  class BadJob < ::Jobs::Base
    attr_accessor :fail_count

    def execute(args)
      @fail_count ||= 0
      @fail_count += 1
      raise StandardError
    end
  end

  it 'handles correct jobs' do
    job = GoodJob.new
    job.perform({})
    expect(job.count).to eq(1)
  end

  it 'handles errors in multisite' do
    RailsMultisite::ConnectionManagement.expects(:all_dbs).returns(['default', 'default', 'default'])
    # one exception per database
    Discourse.expects(:handle_job_exception).times(3)

    bad = BadJob.new
    expect { bad.perform({}) }.to raise_error(Jobs::HandledExceptionWrapper)
    expect(bad.fail_count).to eq(3)
  end

  it 'delegates the process call to execute' do
    ::Jobs::Base.any_instance.expects(:execute).with('hello' => 'world')
    ::Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

  it 'converts to an indifferent access hash' do
    ::Jobs::Base.any_instance.expects(:execute).with(instance_of(HashWithIndifferentAccess))
    ::Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

  context "with fake jobs" do
    let(:common_state) { [] }

    before do
      class Jobs::TestJob1 < Jobs::Base
        def execute(args)
          @@state << "job_1_executed"
        end
      end
      Jobs::TestJob1.class_variable_set(:@@state, common_state)

      class Jobs::TestJob2 < Jobs::Base
        def execute(args)
          @@state << "job_2_started"
          Jobs.enqueue(:test_job_1)
          @@state << "job_2_finished"
        end
      end
      Jobs::TestJob2.class_variable_set(:@@state, common_state)
    end

    after do
      Jobs.send(:remove_const, :TestJob1)
      Jobs.send(:remove_const, :TestJob2)
    end

    it "runs jobs synchronously sequentially in tests" do
      Jobs.run_immediately!
      Jobs.enqueue(:test_job_2)

      expect(common_state).to eq([
        "job_2_started",
        "job_2_finished",
        "job_1_executed"
      ])
    end

  end

end
