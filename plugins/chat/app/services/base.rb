# frozen_string_literal: true

module Chat
  module Service
    module Base
      extend ActiveSupport::Concern

      # The only exception that can be raised by a service.
      class Failure < StandardError
        # @return [Context]
        attr_reader :context

        # @!visibility private
        def initialize(context = nil)
          @context = context
          super
        end
      end

      # @!visibility private
      # Internal class used to hold the contract of the service.
      class Contract
        include ActiveModel::API
        include ActiveModel::Attributes
        include ActiveModel::AttributeMethods

        # @!visibility private
        def self.model_name
          ActiveModel::Name.new(self, nil, "contract")
        end
      end

      # Simple structure to hold the context of the service during its whole lifecycle.
      class Context < OpenStruct
        def success?
          !failure?
        end

        def failure?
          @failure || false
        end

        # Marks the service as failed.
        # @param context [Hash, Context] the context to merge into the current one
        # @example
        #   context.fail!("failure": "something went wrong")
        # @return [Context]
        def fail!(context = {})
          merge(context)
          @failure = true
          raise Failure, self
        end

        # Rolls back the services called in reverse order.
        # @!visibility private
        def rollback!
          return false if @rolled_back
          _called.reverse_each do |service|
            service.instance_eval(&self.class.rollback_block) if self.class.rollback_block
          end
          @rolled_back = true
        end

        # Merges the given context into the current one.
        # @!visibility private
        def merge(other_context = {})
          other_context.each { |key, value| self[key.to_sym] = value }
          self
        end

        # Marks the service as called, so that it can be rolled back.
        # @!visibility private
        def called!(service)
          _called << service
        end

        private

        def self.build(context = {})
          self === context ? context : new(context)
        end

        def _called
          @called ||= []
        end
      end

      # @!visibility private
      module Helpers
        def guardian(name, *args)
          unless context[:guardian].public_send(name, *args)
            context.fail!("guardian.failed" => name)
          end
        end
      end

      included do
        extend ActiveModel::Callbacks
        include Helpers

        attr_reader :context
        attr_reader :contract

        define_model_callbacks :service, :contract
      end

      class_methods do
        attr_reader :contract_block
        attr_reader :service_block
        attr_reader :rollback_block

        def call(context = {})
          new(context).tap(&:run).context
        end

        def call!(context = {})
          new(context).tap(&:run!).context
        end

        def contract(&block)
          @contract_block = block
        end

        def service(&block)
          @service_block = block
        end

        def rollback(&block)
          @rollback_block = block
        end
      end

      # @!scope class
      # @!method contract(&block)
      # Checks the validity of the given context. Supports after/before/around callbacks.
      # Implements ActiveModel::Validations and and ActiveModel::Attributes.
      #
      # @example
      #   before_contract {}
      #   around_contract {}
      #   after_contract {}
      #
      #   contract do
      #     attribute :name
      #     validates :name, presence: true
      #   end

      # @!scope class
      # @!method service(&block)
      # Holds the business logic of the service. Supports after/before/around callbacks.
      #
      # @example
      #   before_service {}
      #   around_service {}
      #   after_service {}
      #
      #   service { context.topic.update!(archived: true) }

      # @!scope class
      # @!method rollback(&block)
      # Called when the service fails, in reverse order of the services called.
      # Supports after/before/around callbacks.
      #
      # @example
      #   before_rollback {}
      #   around_rollback {}
      #   after_rollback {}
      #
      #   rollback { context.topic.update!(archived: false) }

      # @!scope instance
      # @!method guardian(key, *args)
      # Helper to fail the service if the context’s guardian call is invalid.
      # @param key [Symbol] the key of the guardian method to call
      # @param args [Array] the arguments to pass to the guardian method
      #
      # @example
      #   before_contract { guardian(:can_see?, topic) }

      # @!visibility private
      def initialize(initial_context = {})
        @context = Context.build(initial_context)
      end

      private

      def run
        run!
      rescue Failure => exception
        raise if context.object_id != exception.context.object_id
      end

      def run!
        run_callbacks :contract do
          if self.class.contract_block
            contract_class = Class.new(Contract)
            contract_class.class_eval(&self.class.contract_block)
            @contract = contract_class.new(self.context.to_h.except(:guardian))
            self.context[:contract] = contract

            context.fail!("contract.failed" => true) unless contract.valid?
            context.merge(contract.attributes)
          end
        end

        run_callbacks :service do
          instance_eval(&self.class.service_block) if self.class.service_block
          context.called!(self)
        end
      rescue ActiveRecord::Rollback
        context.rollback!
      rescue StandardError
        context.rollback!
        raise
      end
    end
  end
end
