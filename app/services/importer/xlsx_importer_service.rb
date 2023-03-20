# frozen_string_literal: true

require 'open-uri'
require 'roo'

module Importer
  class XlsxImporterService
    COLUMNS = {
      title: 'Title',
      platform: 'Platform',
      territory: 'Territory',
      page: 'Page Name',
      section: 'Section Name',
      spots_in: 'Number of Spots in Section',
      row: 'Row',
      column: 'Column',
      medium_atf: 'Medium ATF',
      true_atf: 'True ATF',
      screenshot: 'Screenshot Link'
    }.freeze

    SOV_COLUMNS = {
      studio: 'App',
      platform: 'Platform',
      territory: 'Territory',
      total_spots: 'Total Number of Spots',
      share_of_voice: '% Share of Voice',
      medium_atf_spots: 'Total Number of Medium Range ATF Spots',
      medium_atf_spots_percentage: '% Medium Range ATF Spots',
      true_atf_spots: 'Total Number of True ATF Spots',
      true_atf_spots_percentage: '% True ATF Spots',
      all_medium_atf_spots: 'Medium ATF Spots on All Studios',
      all_true_atf_spots: 'Total ATF Spots on All Studios'
    }.freeze

    attr_accessor :file_url, :date, :warnings

    def initialize(file_url, date = Time.zone.today)
      @file_url = file_url
      @date = date
      @warnings = 0
    end

    def perform
      result.sheets.each do |sheet|
        next if sheet == 'Total No of Spots'

        result.default_sheet = sheet

        if sheet == 'Share of Voice %'
          import_statistics
        else
          @studio = Studio.find_or_create_by(name: sheet)

          import_spots
        end
      end
    end

    private

    def territory_platform_and_scan(row)
      territory = Territory.where(iso_code: row[:territory]).first
      platform = Platform.where(code: row[:platform]).first
      device = Device.find_or_create_by(territory:, platform:)

      scan = Scan.find_or_initialize_by(
        device:,
        url: file_url,
        scraper: 'XLSX Importer'
      )
      scan.started_at ||= date || DateTime.now
      scan.save

      [territory, platform, scan]
    end

    def import_statistics
      result.each(SOV_COLUMNS) do |sov_row|
        next if sov_row == SOV_COLUMNS

        _territory, _platform, scan = territory_platform_and_scan(sov_row)

        studio = Studio.find_or_create_by(name: sov_row[:studio])

        scan.saved_statistics['studio'] ||= {}
        scan.saved_statistics['studio'][studio.id.to_s] ||= {}
        scan.saved_statistics['studio'][studio.id.to_s]['share_of_voice'] = sov_row[:share_of_voice]
        scan.saved_statistics['medium_atf_spots'] = sov_row[:all_medium_atf_spots]
        scan.saved_statistics['true_atf_spots'] = sov_row[:all_true_atf_spots]
        scan.save
      end
    end

    def import_spots
      result.each(COLUMNS) do |spot_row|
        next if spot_row == COLUMNS

        territory, platform, scan = territory_platform_and_scan(spot_row)

        page = scan.pages.find_or_create_by(
          name: spot_row[:page],
          scraped_at: date,
          platform_identifier: spot_row[:page].parameterize.underscore
        )

        section = page.sections.find_or_create_by(
          name: spot_row[:section],
          position: spot_row[:row],
          spots_count: spot_row[:spots_in]
        )

        title = Title.find_or_create_with_metadata(
          name: spot_row[:title],
          scraper: 'Excel Import',
          platform: platform.code
        )

        publication = Publication.find_or_create_by(territory:, studio: @studio, title:)

        spot = section.spots.find_or_initialize_by(
          title:,
          name: spot_row[:title],
          position: spot_row[:column],
          scraped_at: date
        )

        spot.publications << publication unless spot.publications.include?(publication)

        if spot.new_record?
          spot.medium_atf = spot_row[:medium_atf]&.positive?
          spot.true_atf = spot_row[:true_atf]&.positive?
          spot.save
        end

        begin
          screenshot_file = URI.parse(spot_row[:screenshot].gsub(/\s+/, '%20')).open
          spot.screenshot.attach(io: screenshot_file, filename: 'screenshot.png')
          screenshot_file.rewind
        rescue OpenURI::HTTPError
          SlackClient.send_warning "Screenshot for spot #{spot_row[:title]} (#{spot_row[:screenshot]}) is unreachable."
          self.warnings += 1
          Rails.logger.error "Can't open screenshot #{spot_row[:screenshot]}."
        end

        scan.update(finished_at: DateTime.now)
      end

      SlackClient.send_success "Scan finished #{warnings.positive? ? 'with warnigns' : 'successfully'}: #{self}"
    rescue StandardError => e
      SlackClient.send_error "Scan failed: #{self}"
      SlackClient.send_message e.inspect
      raise e
    end

    def result
      @result ||= Roo::Spreadsheet.open(URI.parse(file_url).open, extension: :xlsx)
    end

    def to_s
      "Scan: #{file_url}; Studio: #{@studio.name}; Date: #{date}; Warnings: #{warnings}"
    end
  end
end
