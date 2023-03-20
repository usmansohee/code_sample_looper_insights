# frozen_string_literal: true

class TitlesController < ApplicationController
  before_action :admin_authorized, except: %i[summary index]
  before_action :set_publication, only: %i[create_favourite_studio show_favourite_studio delete_favourite_studio]

  def summary
    new_params = params[:titles].is_a?(Array) ? params : hash_params
    platform = current_organization.platforms
    platform = platform.where(code: new_params[:platform]) if new_params[:platform].present?
    territory = current_organization.territories
    territory = territory.where(iso_code: new_params[:territory]) if new_params[:territory].present?
    title_ids = []
    dates = []
    new_params[:titles].each do |t|
      title_ids << t[:id]
      start_date = Date.parse(t[:start_date])
      end_date = Date.parse(t[:end_date])
      dates << (start_date == end_date ? start_date : start_date..end_date)
    end

    titles = Title.joins(:publications)
                  .joins(
                    "INNER JOIN competitors_organizations ON publications.studio_id = \
                    #{current_organization.studio_id || 'NULL'} OR \
                    (publications.studio_id = competitors_organizations.studio_id AND \
                    publications.territory_id = competitors_organizations.territory_id AND \
                    competitors_organizations.organization_id = #{current_organization.id} AND \
                    publications.territory_id IN (#{territory.pluck(:id).join(',')}))"
                  )
                  .where(id: title_ids)
                  .distinct
    scans = current_organization.scans.joins(:device).where(devices: { platform:, territory: }, scan_date: dates)
    previous_scans = scans.map(&:previous)
    render json: ScanSerializer.new(current_organization,
                                    (scans | previous_scans).compact,
                                    nil).summary(include_titles: titles)
  end

  def index
    titles = Title.joins(spots: { section: :page })
                  .where(pages: { scan_id: current_organization.scans })
                  .distinct
                  .limit(20)
    titles = titles.search(params[:search]).with_pg_search_rank if params[:search].present?

    render json: { titles: }
  end

  def create
    create_title
    create_artwork
    create_distributor(type: :studio)
    create_distributor(type: :app)

    if @errors.blank?
      render json: { title: @title }
    else
      render json: @errors, status: :unprocessable_entity
    end
  end

  def update
    title = Title.find(params[:id])

    if title.update(title_params)
      render json: { title: }
    else
      render json: { errors: title.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    title = Title.find(params[:id])

    if title.destroy
      render json: { title: }
    else
      render json: { errors: title.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def merge
    title = Title.find(params[:title_id])

    if (destination_title = title.merge_with(title_id: params[:destination_title_id]))
      render json: { title: destination_title }
    else
      render json: { errors: ['No action was performed.'] }, status: :unprocessable_entity
    end
  end

  def similar_titles
    titles = Title.includes(:artworks).joins(:similar_titles).eager_load(:similar_titles).distinct

    render json: { titles: TitleSerializer.new(titles).with_similar_titles }
  end

  def show_favourite_studio
    if @publication.blank?
      render json: { errors: 'no favourite studio found for this title for given territory' }, status: :not_found
    else
      render json: @publication.studio
    end
  end

  def create_favourite_studio
    if @publication&.studio&.id == favourite_studio_params[:studio_id].to_i
      render json: { errors: 'studio is already favourite' }, status: :unprocessable_entity
      return
    end

    publication = Publication.find_or_initialize_by(
      title_id: favourite_studio_params[:title_id],
      territory_id: favourite_studio_params[:territory_id],
      studio_id: favourite_studio_params[:studio_id]
    )

    @publication&.update(favourite: false)
    publication.favourite = true
    if publication.save
      render json: publication.studio
    else
      render json: { errors: publication.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def delete_favourite_studio
    if @publication.blank?
      render json: { errors: 'no favourite studio found for this title for given territory' }, status: :not_found
    else
      @publication.update(favourite: false)
      render json: @publication.studio
    end
  end

  private

  def set_publication
    @publication = Publication.find_by(
      title_id: favourite_studio_params[:title_id],
      territory_id: favourite_studio_params[:territory_id],
      favourite: true
    )
  end

  def favourite_studio_params
    params.permit(:title_id, :territory_id, :studio_id)
  end

  def title_params
    params.permit(:name, :year, :similar_title_id)
  end

  def artwork_params
    params.permit(:image_url, :binary_phash, :territory_id, :territory_code)
  end

  def distributor_params
    params.permit(:studio, :media_app, :territory_id, :territory_code)
  end

  def create_title
    @title = Title.new(title_params)

    @errors ||= {}
    @errors.deep_merge!({ errors: { title: @title.errors.full_messages } }) unless @title.save
  end

  def create_artwork
    return unless artwork_params[:image_url].present? && @title.persisted?

    artwork = Artwork.new(artwork_params)
    artwork.title = @title

    @errors ||= {}
    @errors.deep_merge!({ errors: { artwork: artwork.errors.full_messages } }) unless artwork.save
  end

  def create_distributor(type: :studio)
    distributor_name = distributor_params[type] if type == :studio
    distributor_name = distributor_params[:media_app] if type == :app

    return unless distributor_name.present? && @title.persisted?

    distributor = Studio.find_or_create_by_normalized_name(distributor_name, type)
    territory = Territory.where(id: distributor_params[:territory_id])
                         .or(Territory.where(iso_code: distributor_params[:territory_code]))
                         .first

    @errors ||= {}

    if distributor.valid?
      publication = Publication.new(title: @title, studio: distributor, territory:)

      @errors.deep_merge!({ errors: { publication: publication.errors.full_messages } }) unless publication.save
    else
      @errors.deep_merge!({ errors: { studio: distributor.errors.full_messages } })
    end
  end

  def hash_params
    params_array = []
    params[:titles].each_key do |k|
      params_array << {
        id: params[:titles][k][:id],
        start_date: params[:titles][k][:start_date],
        end_date: params[:titles][k][:end_date]
      }
    end

    {
      titles: params_array,
      platform: params[:platform],
      territory: params[:territory]
    }
  end
end
