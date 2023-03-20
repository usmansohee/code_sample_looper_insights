# frozen_string_literal: true

class DevicesController < ApplicationController
  before_action :admin_authorized

  def index
    render json: { devices: Device.all }
  end

  def create
    device = Device.new(device_params)

    if device.save
      render json: device
    else
      render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    device = Device.find(params[:id])
    render json: device.destroy
  end

  private

  def device_params
    params.permit(:territory_id, :platform_id)
  end
end
