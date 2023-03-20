# frozen_string_literal: true

class StudiosController < ApplicationController
  before_action :admin_authorized, only: %i[update create destroy]
  before_action :set_territories_param, only: %i[update create]

  def index
    render json: { studios: admin_logged_in? ? Studio.with_attached_logo.order(:name) : [current_organization.studio] }
  end

  def show
    studio = admin_logged_in? ? Studio.with_attached_logo.find(params[:id]) : current_organization.studio
    render json: { studio: }
  end

  def create
    territories = Territory.where(iso_code: studio_params[:territories])
    studio = Studio.new(studio_params.merge(territories:))

    if studio.save
      studio.logo.attach(params[:logo]) if params[:logo].present?
      studio.alternate_logo.attach(params[:alternate_logo]) if params[:alternate_logo].present?
      render json: studio
    else
      render json: { errors: studio.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    territories = Territory.where(iso_code: studio_params[:territories])
    studio = Studio.find(params[:id])

    if studio.update(studio_params.merge(territories:))
      studio.logo.attach(params[:logo]) if params[:logo].present?
      studio.alternate_logo.attach(params[:alternate_logo]) if params[:alternate_logo].present?
      render json: studio
    else
      render json: { errors: studio.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    studio = Studio.find(params[:id])
    render json: studio.destroy
  end

  private

  def studio_params
    (params[:studio] || params).permit(
      :name,
      :gradient_color_start,
      :gradient_color_end,
      :user_id,
      :distributor_type,
      territories: []
    )
  end

  def set_territories_param
    params[:territories] = params[:territories]&.split(',') unless params[:territories].is_a?(Array)
  end
end
