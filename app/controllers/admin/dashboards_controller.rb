class Admin::DashboardsController < ApplicationController
  def show
    authorize User, :index?
  end
end
