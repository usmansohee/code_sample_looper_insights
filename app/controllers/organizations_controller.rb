# frozen_string_literal: true

class OrganizationsController < ApplicationController
  before_action :admin_authorized, only: %i[index create destroy]
  before_action :split_ids, only: %i[create update]

  def index
    render json: { organizations: Organization.with_attached_logo.order(:name) }
  end

  def show
    organization = Organization.with_attached_logo.find(params[:id]) if params[:id].present? && admin_logged_in?
    render json: { organization: organization || current_organization }
  end

  def create
    @organization = Organization.new(org_params)

    if @organization.save
      set_competitors
      render json: { organization: @organization }, status: :created
    else
      render json: { error: @organization.errors.messages }, status: :unprocessable_entity
    end
  end

  def update
    @organization = params[:id].present? && admin_logged_in? ? Organization.find(params[:id]) : current_organization

    if @organization.update(org_params)
      set_competitors
      render json: { organization: @organization }
    else
      render json: { error: @organization.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    organization = Organization.find(params[:id])
    render json: organization.destroy
  end

  private

  def org_params
    params.permit(:name, :gradient_color_start, :gradient_color_end,
                  :logo_image, :logo_url, :studio_id, :start_date,
                  :dashboard_enabled, :core_enabled,
                  device_ids: [],
                  organizations_scan_dates_attributes: %i[id organization_id scan_days start_date end_date _destroy])
  end

  def split_ids
    params[:device_ids] = params.delete(:devices).split(',') if params[:devices].present?
  end

  def set_competitors
    return if params[:competitors].blank?

    deletions = @organization.competitors_organizations

    params[:competitors].each do |competitor|
      territory_ids = Territory.where(iso_code: competitor[:territories]&.split(',')).pluck(:id)

      deletions = deletions.where.not(
        studio_id: competitor[:id], territory_id: territory_ids
      )

      territory_ids.each do |territory_id|
        @organization.competitors_organizations.find_or_create_by(studio_id: competitor[:id], territory_id:)
      end
    end

    deletions.delete_all
  end
end
