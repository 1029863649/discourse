# frozen_string_literal: true
module Chat
  module WithServiceHelper
    def result
      @_result
    end

    # @param service [Class] A class including {Chat::Service::Base}
    # @param dependencies [kwargs] Any additional params to load into the service context,
    #   in addition to controller @params. If using outside of a controller, then the params
    #   needed for .call must all be passed here, including guardian.
    def with_service(service, default_actions: true, **dependencies, &block)
      object = self
      merged_block =
        proc do
          instance_exec(&object.method(:default_actions_for_service).call) if default_actions
          instance_exec(&(block || proc {}))
        end
      ServiceRunner.call(service, object, **dependencies, &merged_block)
    end

    def run_service(service, dependencies)
      @_result =
        service.call(
          params_if_present.merge(guardian: dependencies[:guardian] || guardian, **dependencies),
        )
    end

    def default_actions_for_service
      proc {}
    end

    def params_if_present
      return {} if !defined?(params)
      params.to_unsafe_h
    end
  end
end
