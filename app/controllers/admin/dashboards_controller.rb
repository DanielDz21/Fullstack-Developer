class Admin::DashboardsController < ApplicationController
  def show
    authorize User, :index?
    @total_users = User.count
    @users_by_role = User.group(:role).count
  end
end
