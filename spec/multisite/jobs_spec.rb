require 'rails_helper'

RSpec.describe "Running Sidekiq Jobs in Multisite", type: :multisite do
  let(:conn) { RailsMultisite::ConnectionManagement }

  it 'should revert back to the default connection' do
    expect do
      Jobs::DestroyOldDeletionStubs.new.perform({})
    end.to_not change { RailsMultisite::ConnectionManagement.current_db }
  end
end
