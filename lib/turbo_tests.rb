require 'open3'
require 'fileutils'
require 'json'
require 'rspec'
require 'rails'

require 'parallel_tests'
require 'parallel_tests/rspec/runner'

require './lib/turbo_tests/reporter'

module TurboTests
  FakeException = Struct.new(:backtrace, :message, :cause)
  class FakeException
    def self.from_obj(obj)
      if obj
        obj = obj.symbolize_keys
        new(
          obj[:backtrace],
          obj[:message],
          obj[:cause]
        )
      end
    end
  end

  FakeExecutionResult = Struct.new(:example_skipped?, :pending_message, :status, :pending_fixed?, :exception)
  class FakeExecutionResult
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      new(
        obj[:example_skipped?],
        obj[:pending_message],
        obj[:status].to_sym,
        obj[:pending_fixed?],
        FakeException.from_obj(obj[:exception])
      )
    end
  end

  FakeExample = Struct.new(:execution_result, :location, :full_description, :metadata, :location_rerun_argument)
  class FakeExample
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      new(
        FakeExecutionResult.from_obj(obj[:execution_result]),
        obj[:location],
        obj[:full_description],
        obj[:metadata].symbolize_keys,
        obj[:location_rerun_argument],
      )
    end

    def notification
      RSpec::Core::Notifications::ExampleNotification.for(
        self
      )
    end
  end

  class Runner
    def self.run(formatter_config, files, start_time=Time.now)
      reporter = Reporter.from_config(formatter_config, start_time)

      new(reporter, files).run
    end

    def initialize(reporter, files)
      @reporter = reporter
      @files = files
      @messages = Queue.new
    end

    def run
      @num_processes = ParallelTests.determine_number_of_processes(nil)

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(
          @files,
          @num_processes,
          group_by: :filesize
        )

      setup_tmp_dir

      tests_in_groups.each_with_index do |tests, process_num|
        start_subprocess(tests, process_num + 1)
      end

      handle_messages

      @reporter.finish
    end

    protected

    def setup_tmp_dir
      begin
        FileUtils.rm_r('tmp/test-pipes')
      rescue Errno::ENOENT
      end

      FileUtils.mkdir_p('tmp/test-pipes/')
    end

    def start_subprocess(tests, process_num)
      if tests.empty?
        @messages << {type: 'exit', process_num: process_num}
      else
        begin
          File.mkfifo("tmp/test-pipes/subprocess-#{process_num}")
        rescue Errno::EEXIST
        end

        stdin, stdout, stderr, wait_thr =
          Open3.popen3(
            {'TEST_ENV_NUMBER' => process_num.to_s},
            "bundle", "exec", "rspec",
            "-f", "JsonRowsFormatter",
            "-o", "tmp/test-pipes/subprocess-#{process_num}",
            *tests
          )

        Thread.new do
          File.open("tmp/test-pipes/subprocess-#{process_num}") do |fd|
            fd.each_line do |line|
              message = JSON.parse(line)
              message = message.symbolize_keys
              message[:process_num] = process_num
              @messages << message
            end
          end

          @messages << {type: 'exit', process_num: process_num}
        end

        Thread.new do
          while true
            begin
              msg = stdout.readpartial(4096)
            rescue EOFError
              break
            else
              STDOUT.write(msg)
            end
          end
        end

        Thread.new do
          while true
            begin
              msg = stderr.readpartial(4096)
            rescue EOFError
              break
            else
              STDERR.write(msg)
            end
          end
        end
      end
    end

    def handle_messages
      exited = 0

      begin
        while true
          message = @messages.pop
          case message[:type]
          when 'example_passed'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_passed(example)
          when 'example_pending'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_pending(example)
          when 'example_failed'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_failed(example)
          when 'seed'
          when 'close'
          when 'exit'
            exited += 1
            if exited == @num_processes
              break
            end
          else
            STDERR.puts("Unhandled message in main process: #{message}")
          end

          STDOUT.flush
        end
      rescue Interrupt
      end
    end
  end
end
