# frozen_string_literal: true

class DeviceOrganizationsScanDatesController < ApplicationController
  before_action :admin_authorized
  before_action :set_devices_organization, only: %i[create update]

  def create
    device_organizations_scan_date = DeviceOrganizationsScanDate.new(
      modified_device_organization_params
    )
    if device_organizations_scan_date.save
      render json: device_organizations_scan_date
    else
      render json: { errors: device_organizations_scan_date.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    device_organizations_scan_date = DeviceOrganizationsScanDate.find(params[:id])

    if device_organizations_scan_date.update(modified_device_organization_params)
      render json: device_organizations_scan_date
    else
      render json: { errors: device_organizations_scan_date.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    device_organizations_scan_date = DeviceOrganizationsScanDate.find(params[:id])
    render json: device_organizations_scan_date.destroy
  end

  private

  def set_devices_organization
    return unless device_organization_params[:device_id] && device_organization_params[:organization_id]

    @devices_organization = DevicesOrganization.find_by(
      device_id: device_organization_params[:device_id],
      organization_id: device_organization_params[:organization_id]
    )
    return if @devices_organization

    render json: { errors: 'This organization does not have access to the provided device.
    To check available devices you need to hit /organizations/:id endpoint and look for
    the devices key' }, status: :not_found
  end

  def device_organization_params
    params.permit(:scan_days, :start_date, :end_date, :device_id, :organization_id)
  end

  def modified_device_organization_params
    if device_organization_params[:device_id] && device_organization_params[:organization_id]
      device_organization_params.except(:device_id, :organization_id)
        .merge(devices_organization_id: @devices_organization.id)
    else
      device_organization_params
    end
  end
end
