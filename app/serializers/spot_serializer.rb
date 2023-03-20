# frozen_string_literal: true

class SpotSerializer
  attr_accessor :spots, :organization_studio, :allowed_distributors

  def initialize(spots, organization_studio, allowed_distributors = nil)
    @spots = spots
    @organization_studio = organization_studio
    @allowed_distributors = allowed_distributors
  end

  def as_json
    spots.map do |spot|
      competitors = allowed_distributors && allowed_distributors[spot.territory.id]

      studio = spot.studio if spot.studio&.id == organization_studio&.id || competitors&.include?(spot.studio&.id)
      app = spot.app if spot.app&.id == organization_studio&.id || competitors&.include?(spot.app&.id)

      {
        id: spot.id,
        studio: studio.as_json(only: %i[id name], methods: nil),
        app: app.as_json(only: %i[id name], methods: nil),
        territory: spot.territory.as_json(only: %i[id name iso_code]),
        platform: spot.platform.as_json(only: %i[id name code]),
        title: spot.name,
        page_name: spot.breadcrumbs.join(' / '),
        page_size: spot.breadcrumbs&.count,
        spots_in_section: spot.section.spots_count,
        row_position: spot.row,
        column_position: spot.column,
        medium_atf: spot.medium_atf ? 1 : 0,
        true_atf: spot.true_atf ? 1 : 0,
        screenshot: spot.screenshot.present? ? Rails.application.routes.url_helpers.url_for(spot.screenshot) : '',
        scraped_at: spot.scraped_at,
        scan_date: spot.scan.scan_date,
        mpv: spot.mpv.to_f
      }
    end
  end
end
