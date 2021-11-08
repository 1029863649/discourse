# frozen_string_literal: true
class AssociatedGroup < ActiveRecord::Base
  has_many :user_associated_groups, dependent: :destroy
  has_many :users, through: :user_associated_groups
  has_many :group_associated_groups, dependent: :destroy
  has_many :groups, through: :group_associated_groups

  def label
    "#{name}:#{provider_name}#{provider_id ? ":#{provider_id}" : ""}"
  end

  def self.has_provider?
    Discourse.enabled_authenticators.any? { |a| a.provides_groups? }
  end
end

# == Schema Information
#
# Table name: associated_groups
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  provider_name   :string           not null
#  provider_id     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  associated_groups_name_provider  (name,provider_name,provider_id) UNIQUE
#
