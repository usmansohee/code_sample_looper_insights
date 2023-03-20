# frozen_string_literal: true

class ArtworksController < ApplicationController
  before_action :admin_authorized, only: %i[create]

  def create
    territory_id = artwork_params[:territory_id].presence
    territory_id ||= Territory.find_by(iso_code: artwork_params[:territory_code])&.id

    if (artwork = Artwork.find_by(binary_phash: artwork_params[:binary_phash], territory_id:))
      render json: { artwork: artwork.as_json(methods: %i[image_url territory_code]) }
    else
      artwork = Artwork.new(artwork_params)
      if artwork.save
        render json: { artwork: artwork.as_json(methods: %i[image_url territory_code]) }
      else
        render json: { errors: artwork.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def update
    artwork = Artwork.find(params[:id])

    if artwork.update(artwork_params)
      render json: { artwork: artwork.as_json(methods: %i[image_url territory_code]) }
    else
      render json: { errors: artwork.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def artwork_params
    params.permit(:title_id, :territory_id, :territory_code, :binary_phash, :image, :image_url)
  end
end
