class ProfilesController < ApplicationController
  def show
    @user = Current.user
    authorize @user
  end
end
