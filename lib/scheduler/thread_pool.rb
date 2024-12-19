# frozen_string_literal: true

module Scheduler
  # ThreadPool manages a pool of worker threads that process tasks from a queue.
  # It maintains a minimum number of threads and can scale up to a maximum number
  # when there's more work to be done.
  class ThreadPool
    class ShutdownError < StandardError
    end

    def initialize(min_threads:, max_threads:, idle_time:)
      raise ArgumentError, "min_threads must be positive" if min_threads <= 0
      raise ArgumentError, "max_threads must be >= min_threads" if max_threads < min_threads
      raise ArgumentError, "idle_time must be positive" if idle_time <= 0

      @min_threads = min_threads
      @max_threads = max_threads
      @idle_time = idle_time

      @threads = []
      @queue = Queue.new
      @mutex = Mutex.new
      @new_work = ConditionVariable.new
      @shutdown = false

      # Initialize minimum number of threads
      @min_threads.times { spawn_thread }
    end

    def post(&block)
      raise ShutdownError, "Cannot post work to a shutdown ThreadPool" if shutdown?

      db = RailsMultisite::ConnectionManagement.current_db
      wrapped_block = wrap_block(block, db)

      @mutex.synchronize do
        @queue << wrapped_block
        @new_work.signal
        spawn_thread if @threads.size < @max_threads
      end
    end

    def shutdown(timeout: 30)
      @mutex.synchronize do
        @shutdown = true
        @threads.size.times { @queue << :shutdown }
        @new_work.broadcast
      end

      # Copy threads array to avoid concurrent modification
      threads_to_join = nil
      @mutex.synchronize { threads_to_join = @threads.dup }

      failed_to_shutdown = false

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      threads_to_join.each do |thread|
        remaining_time = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        break if remaining_time <= 0
        if !thread.join(remaining_time)
          Rails.logger.error "ThreadPool: Failed to join thread within timeout"
          failed_to_shutdown = true
        end
      end

      raise ShutdownError, "Failed to shutdown ThreadPool within timeout" if failed_to_shutdown
    end

    def shutdown?
      @shutdown
    end

    def stats
      @mutex.synchronize do
        {
          active_threads: @threads.size,
          queued_tasks: @queue.size,
          shutdown: @shutdown,
          min_threads: @min_threads,
          max_threads: @max_threads,
        }
      end
    end

    private

    def wrap_block(block, db)
      proc do
        begin
          RailsMultisite::ConnectionManagement.with_connection(db) { block.call }
        rescue StandardError => e
          Discourse.warn_exception(
            e,
            message: "Discourse Scheduler ThreadPool: Unhandled exception",
          )
        end
      end
    end

    def thread_loop
      done = false
      while !done
        work = nil

        @mutex.synchronize do
          @new_work.wait(@mutex, @idle_time)

          if @queue.empty?
            if @threads.size > @min_threads
              @threads.delete(Thread.current)
              done = true
              break
            end
          else
            work = @queue.pop

            if work == :shutdown
              @threads.delete(Thread.current)
              done = true
              break
            end
          end
        end

        # could be nil if the thread just needs to idle
        work&.call if !done
      end
    end

    # note this is called from inside a mutex, no need to synchronize
    def spawn_thread
      thread = Thread.new { thread_loop }
      thread.abort_on_exception = true

      @threads << thread
    end
  end
end
