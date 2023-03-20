# frozen_string_literal: true

require 'open-uri'

module Importer
  class DataImporterService
    attr_accessor :result_json, :force_strategy

    def initialize(result_json, force_strategy = nil)
      @result_json = result_json
      @force_strategy = force_strategy
    end

    def perform
      force_strategy == :delete ? delete_scan : create_scan
    end

    private

    def db_scan
      return @db_scan if @db_scan.present?

      matching_scans = Scan.where(
        device:,
        scraper: result['scan']['scraper'],
        scan_date: result['scan']['scanDate']
      ).to_a

      return if matching_scans.blank?

      @db_scan = matching_scans.shift
      Page.where(scan_id: matching_scans).update_all(scan_id: @db_scan.id)
      matching_scans.map(&:destroy)
      @db_scan.reload
    end

    def device
      @device ||= Device.find_or_create_by(platform:, territory:)
    end

    def platform
      @platform ||= Platform.where(code: result['scan']['store']).or(
        Platform.where(name: result['scan']['store'])
      ).first
    end

    def territory
      @territory ||= Territory.where(iso_code: result['scan']['store_variant']).first
    end

    def find_existing_pages_for(page)
      db_scan.pages.where(platform_identifier: page['id'], name: page['name']).or(
        db_scan.pages.where(platform_identifier: page['obsolete_identifier'])
      )
    end

    def create_scan
      Rails.logger.debug '====================================='
      Rails.logger.debug { "Importing scan #{result['scan']['id']}" }
      Rails.logger.debug { "Pages: #{result['pages'].map { |p| p['name'] }.to_sentence}" } if result['pages']
      Rails.logger.debug '====================================='

      return unless (scan = import_scan)

      import_pages
      notify_slack
    ensure
      UpdateStatsScanJob.perform_later(id: scan.id) if scan
    end

    def delete_scan
      return unless db_scan

      Rails.logger.debug '====================================='
      Rails.logger.debug { "Deleting scan #{result['scan']['id']}" }
      Rails.logger.debug { "Pages: #{result['pages'].map { |p| p['name'] }.to_sentence}" } if result['pages']
      Rails.logger.debug '====================================='

      result['pages'].each do |page|
        existing_pages = find_existing_pages_for(page)

        artwork_ids = Artwork.joins(spots: :section).where(sections: { page_id: existing_pages }).pluck(:id)
        title_ids = Title.joins(spots: :section).where(sections: { page_id: existing_pages }).pluck(:id)

        delete_existing_pages(existing_pages) if existing_pages.present?

        Artwork.where(id: artwork_ids).left_outer_joins(:spots).having('COUNT(spots.id) = 0').group(:id).destroy_all
        Title.where(id: title_ids).left_outer_joins(:spots).having('COUNT(spots.id) = 0').group(:id).destroy_all
      end

      db_scan.destroy! if db_scan.pages.blank?
    end

    def delete_existing_pages(existing_pages)
      Rails.logger.debug '====================================='
      Rails.logger.debug { "Deleting #{existing_pages.count} existing pages:" }
      Rails.logger.debug { "Names: #{existing_pages.map(&:name).to_sentence}" }
      Rails.logger.debug '====================================='

      existing_pages.delete_all
    end

    def import_scan
      return if result['pages'].blank?

      start_time = result['scan']['startTime']
      end_time = result['scan']['endTime']

      if db_scan
        db_scan.update(started_at: start_time) if db_scan.started_at > DateTime.parse(start_time)
        db_scan.update(finished_at: end_time) if end_time &&
                                                 (db_scan.finished_at.blank? ||
                                                 db_scan.finished_at < DateTime.parse(end_time))
      else
        @db_scan = Scan.create!(
          device:,
          scraper: result['scan']['scraper'],
          url: result['scan']['url'],
          started_at: start_time,
          finished_at: end_time,
          scan_date: result['scan']['scanDate']
        )
      end

      result['scan']['db_id'] = db_scan.id
      db_scan
    end

    def import_pages
      result['pages'].each do |page|
        existing_pages = find_existing_pages_for(page)

        strategy = force_strategy

        if existing_pages.present?
          delete_existing_pages(existing_pages)

          strategy = :update if force_strategy.blank?
        elsif force_strategy.blank?
          strategy = :create
        end

        Rails.logger.debug '====================================='
        Rails.logger.debug { "Importing page #{page['name']} (#{page['id']})" }
        Rails.logger.debug { "Strategy: #{strategy}" }
        Rails.logger.debug '====================================='

        db_page = @db_scan.pages.create!(
          platform_identifier: page['id'],
          name: page['name'],
          scraped_at: page['scrape_time'] && DateTime.parse(page['scrape_time'])
        )

        page['db_id'] = db_page.id

        page['sections']&.each do |section|
          db_section = db_page.sections.find_or_create_by(
            name: section['name'].split('\n')[0],
            subtitle: section['name'].split('\n')[1],
            position: section['position']
          )

          db_section.spots_count = nil

          section['db_id'] = db_section.id

          spots = section['spots']&.map do |spot|
            details = if spot['destination']&.fetch('page_type') == 'detail'
                        result['details']&.find { |d| d['id'] == spot['destination']['page_id'] }
                      end || {}

            name = spot['name'].presence || details['name']
            year = spot['year'].presence || details['year']
            description = spot['description'].presence || details['description']
            studio_name = spot['studio'].presence || details['studio']
            app_name = spot['app'].presence || details['app']

            Rails.logger.debug '====================================='
            Rails.logger.debug 'Importing spot:'
            Rails.logger.debug { "Name: #{name}; Year: #{year}; Studio: #{studio_name}; App: #{app_name}" }
            Rails.logger.debug '====================================='

            studio = Studio.find_or_create_by_normalized_name(studio_name, 'studio') if studio_name.present?
            app = Studio.find_or_create_by_normalized_name(app_name, 'app') if app_name.present?

            thumbnail = details['thumbnail_images']
            artwork_url = spot['artwork_url'].presence || thumbnail&.first&.fetch('url', nil)
            if artwork_url.present?
              phash = spot['artwork_phash'].presence || thumbnail&.first&.fetch('phash', nil)
              artwork = Artwork.find_or_initialize_by(
                territory: @territory,
                binary_phash: Artwork.convert_phash(phash)
              )
              if artwork.persisted?
                Rails.logger.debug '====================================='
                Rails.logger.debug 'Existing Artwork Found:'
                Rails.logger.debug do
                  "Title: #{artwork.title.name}; ID: #{artwork.id};  Phash: #{artwork.binary_phash}."
                end
                Rails.logger.debug '====================================='
              end
            end

            title ||= Title.find_by(id: spot['title_id'])

            if title && artwork&.title && title != artwork.title && !artwork.title.similar_title
              artwork.title.update(similar_title: title)
            end

            title ||= artwork&.title

            title&.metadata&.deep_merge({
                                          result['scan']['scraper'] => {
                                            platform.code => {
                                              'title' => name,
                                              'platform_id' => spot['platform_identifier'],
                                              'description' => description
                                            }
                                          }
                                        })

            title ||= Title.find_or_create_with_metadata(
              name:,
              year:,
              scraper: result['scan']['scraper'],
              platform: platform.code,
              metadata: {
                platform_id: spot['platform_identifier'],
                description:
              }
            )

            unless title.valid?
              Rails.logger.debug '====================================='
              Rails.logger.debug 'Title is invalid and will not be saved:'
              Rails.logger.debug { "Spot: #{spot.inspect}" }
              Rails.logger.debug { "Title: #{title.inspect}" }
              Rails.logger.debug { "Errors: #{title.errors.full_messages.to_sentence}" }
              Rails.logger.debug '====================================='
            end

            if artwork.present?
              artwork.title = title
              artwork.image_url = artwork_url if artwork.new_record?
              artwork.save
            end

            studio_pub = Publication.find_or_create_by(territory:, title:, studio:) if studio

            if app
              app_pub = Publication.find_or_create_by(
                territory:,
                title:,
                studio: app
              )
            end

            db_spot = db_section.spots.find_or_initialize_by(
              artwork:,
              position: spot['position']
            )
            db_spot.name = name
            db_spot.title = title
            db_spot.publications << studio_pub if studio_pub && db_spot.studio.blank?
            db_spot_app = db_spot.app.blank?
            db_spot.publications << app_pub if app_pub && db_spot_app
            db_spot.scraped_at = spot['scrape_time'] && DateTime.parse(spot['scrape_time'])
            db_spot.description = description
            db_spot.metadata = {
              platform_id: spot['platform_identifier'],
              year:,
              studio: studio_name
            }

            screenshot = if spot['screenshot_url'].present?
                           URI.parse(spot['screenshot_url'])
                         elsif artwork_url.present?
                           URI.parse(artwork_url)
                         end

            { record: db_spot, screenshot: }
          rescue ActiveRecord::RecordNotSaved => e
            Rails.logger.debug '====================================='
            Rails.logger.debug { "Importer exception raised: #{e}" }
            Rails.logger.debug { "Scan: #{db_scan.inspect}" }
            Rails.logger.debug { "Page: #{db_page.inspect}" }
            Rails.logger.debug { "Section: #{db_section.inspect}" }
            Rails.logger.debug { "Spot: #{db_spot.inspect}" }
            Rails.logger.debug { "Artwork: #{artwork.inspect}" }
            Rails.logger.debug { "Title: #{title.inspect}" }
            Rails.logger.debug '====================================='
            raise e
          end

          if spots&.any?
            valid_spots = spots.select { |s| s[:record].valid? }
            valid_spots.each do |s|
              s[:record].run_callbacks(:create) { false }
              s[:record].run_callbacks(:save) { false }
            end
            Spot.import valid_spots.pluck(:record), batch_size: 50, validate: false
            valid_spots.each { |s| s[:record].screenshot.attach(io: s[:screenshot].open, filename: 'screenshot.png') }
          end
        end
      end
    end

    def notify_slack
      SlackClient.send_success "Scan finished successfully. #{self}"
    end

    def to_s
      "Scan: #{result['scan']['url']}; Date: #{result['scan']['startTime']}"
    end

    def result
      @result ||= JSON.parse(result_json)
    end
  end
end
