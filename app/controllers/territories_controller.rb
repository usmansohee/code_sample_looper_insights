# frozen_string_literal: true

class TerritoriesController < ApplicationController
  before_action :admin_authorized

  def index
    render json: { territories: Territory.all }
  end

  def create
    territory = Territory.new(territory_params)

    if territory.save
      render json: territory
    else
      render json: { errors: territory.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    territory = Territory.find(params[:id])

    if territory.update(territory_params)
      render json: territory
    else
      render json: { errors: territory.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    territory = Territory.find(params[:id])
    render json: territory.destroy
  end

  private

  def territory_params
    params.permit(:name, :iso_code)
  end
end
