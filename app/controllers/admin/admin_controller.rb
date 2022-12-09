# frozen_string_literal: true

class Admin::AdminController < ApplicationController
  requires_login
  before_action :ensure_admin

  def index
    render body: nil
  end

end
