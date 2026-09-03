class Admin::DashboardsController < ApplicationController
  before_action :require_admin

  def show
  end

  private
    def require_admin
      head :forbidden unless Current.user.admin?
    end
end
