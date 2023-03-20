# frozen_string_literal: true

class ScansController < RenderController
  before_action :find_scans, only: %i[summary weekly_summary dates]
  before_action :admin_authorized, only: %i[destroy create update_stats]

  def summary
    if params[:format].present? && params[:format] == 'xlsx'
      @studios = current_organization.accessible_studios.find(studio_ids)

      @platforms = platforms
      @territories = territories

      territory_for_filename = @territories.map(&:iso_code).join('-')
      platform_for_filename = @platforms.map { |p| p.name.parameterize.underscore.camelize }.join('-')
      date_for_filename = search_params[:dates]&.join

      render xlsx: 'summary',
             filename: "MOTM#{territory_for_filename}#{platform_for_filename}#{date_for_filename}",
             disposition: 'attachment'
    elsif stale?(@scans)
      render json: ScanSerializer.new(current_organization, @scans, studio_ids).summary
    end
  end

  def weekly_summary
    return unless stale?(@scans)

    render json: ScanSerializer.new(current_organization, @scans, studio_ids)
                               .weekly_summary(params, platforms, territories)
                               .as_json(except: :scans)
  end

  def dates
    @scans = @scans.select('scan_date').distinct.where.not(scan_date: nil)
    render json: @scans.map { |d| d.scan_date.strftime('%Y-%m-%d') }
  end

  def create
    ImportScanJob.perform_later(url: params[:url], type: params[:type], date:)
  end

  def update_stats
    UpdateStatsScanJob.perform_later(id: params[:id])
  end

  def destroy
    DeleteScanJob.perform_later(url: params[:url])
  end

  private

  def studio_ids
    if search_params[:studio_ids].present?
      search_params[:studio_ids] & current_organization.accessible_studios.map(&:id)
    else
      current_organization.accessible_studios.map(&:id)
    end
  end

  def platforms
    platforms = current_organization.platforms
    platforms = platforms.where(code: search_params[:platform_codes]) if search_params[:platform_codes].present?
    platforms
  end

  def territories
    territories = current_organization.territories
    if search_params[:territory_iso_codes].present?
      territories = territories.where(iso_code: search_params[:territory_iso_codes])
    end
    territories
  end

  def date
    (params[:date] && Date.parse(params[:date])) || Time.zone.today
  end

  def search_params
    search_params = params.permit(:dates, :studio_ids, :platform_codes, :territory_iso_codes, :start_date, :end_date)
    search_params[:dates] = search_params[:dates]&.split(',')
    search_params[:studio_ids] = search_params[:studio_ids]&.split(',')&.map(&:to_i)
    search_params[:platform_codes] = search_params[:platform_codes]&.split(',')
    search_params[:territory_iso_codes] = search_params[:territory_iso_codes]&.split(',')
    search_params
  end

  def find_scans
    @scans = current_organization.scans.search(search_params)
  end
end
