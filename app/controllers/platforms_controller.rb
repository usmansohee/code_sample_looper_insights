# frozen_string_literal: true

class PlatformsController < ApplicationController
  before_action :admin_authorized

  def index
    render json: { platforms: Platform.all }
  end

  def create
    platform = Platform.new(platform_params)

    if platform.save
      render json: platform
    else
      render json: { errors: platform.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    platform = Platform.find(params[:id])

    if platform.update(platform_params)
      render json: platform
    else
      render json: { errors: platform.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    platform = Platform.find(params[:id])
    render json: platform.destroy
  end

  private

  def platform_params
    params.permit(:name, :code)
  end
end
