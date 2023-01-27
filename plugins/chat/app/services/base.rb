# frozen_string_literal: true

module Chat
  module Service
    module Base
      extend ActiveSupport::Concern

      class Failure < StandardError
        attr_reader :context

        def initialize(context = nil)
          @context = context
          super
        end
      end

      class Contract
        include ActiveModel::API
        include ActiveModel::Attributes
        include ActiveModel::AttributeMethods

        # @!visibility private
        def self.model_name
          ActiveModel::Name.new(self, nil, "contract")
        end

        def initialize(params)
          super(params)
          change_attribute_defaults(params.with_indifferent_access)
        end

        def change_attribute_defaults(params)
          # TODO: Not sure if there is a cleaner way to do this, also maybe
          # a different name?
          #
          # Should be overridden by the contract if necessary.
          #
          # Can be used to inspect keys etc on the original params
          # and set attribute values accordingly. for example, if a key
          # is missing, we may not want to set the attribute to nil,
          # but rather keep its original value based on a model
        end
      end

      class Context < OpenStruct
        def self.build(context = {})
          self === context ? context : new(context)
        end

        def success?
          !failure?
        end

        def failure?
          @failure || false
        end

        def fail!(context = {})
          merge(context)
          @failure = true
          raise Failure, self
        end

        def rollback!
          return false if @rolled_back
          _called.reverse_each do |service|
            service.instance_eval(&self.class.rollback_block) if self.class.rollback_block
          end
          @rolled_back = true
        end

        def merge(other_context = {})
          other_context.each { |key, value| self[key.to_sym] = value }
          self
        end

        def called!(service)
          _called << service
        end

        private

        def _called
          @called ||= []
        end
      end

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

      # @!method guardian(key, *args)
      # Helper to fail the service if the guardian call is invalid
      #
      # @example
      #   guardian(:can_see?, topic)

      # @!scope class
      # @!method contract(&block)
      # Checks the validity of the given context.
      # Implements ActiveModel::Validations and ActiveModel::Attributes.
      #
      # @example
      #   contract do
      #     attribute :name
      #     validates :name, presence: true
      #   end

      # @!scope class
      # @!method service(&block)
      # Holds the business logic of the service
      #
      # @example
      #   service { context.topic.update!(archived: true) }

      # @!scope class
      # @!method rollback(&block)
      # Called when the service fails, in reverse order of the services called
      #
      # @example
      #   rollback { context.topic.update!(archived: false) }

      # @!visibility private
      def initialize(initial_context = {})
        @context = Context.build(initial_context)

        if self.class.contract_block
          contract_class = Class.new(Contract)
          contract_class.class_eval(&self.class.contract_block)
          @contract = contract_class.new(initial_context.except(:guardian))
          self.context[:contract] = contract
        end
      end

      private

      def run
        run!
      rescue Failure => exception
        raise if context.object_id != exception.context.object_id
      end

      def run!
        run_callbacks :contract do
          if contract
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
