# frozen_string_literal: true

# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  finished_at     :datetime
#  metadata        :jsonb
#  report_type     :string           default("xlsx")
#  started_at      :datetime
#  status          :string           default("queued")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#
# Indexes
#
#  index_reports_on_finished_at      (finished_at)
#  index_reports_on_organization_id  (organization_id)
#  index_reports_on_status           (status)
#
class Report < ApplicationRecord
  REPORT_TYPES = %w[xlsx xlsx_sov xlsx_distributors csv_sov csv_distributors].freeze
  STATUSES = %w[queued in_progress completed failed cancelled].freeze
  WEEKDAY_START = 0 # Sunday
  WEEKDAY_END = 6 # Saturday

  belongs_to :organization

  has_one_attached :report_file

  validates :report_type, presence: true, inclusion: REPORT_TYPES
  validates :status, presence: true, inclusion: STATUSES
  validate :pending_count_validation, on: :create

  scope :pending, -> { where(status: %w[queued in_progress]) }

  delegate :accessible_studios, to: :organization

  def as_json(options = {})
    super(options.merge(methods: %i[report_file_url report_filename]))
  end

  def report_file_url
    Rails.application.routes.url_helpers.url_for(report_file) if report_file.present?
  end

  def report_filename
    return report_file.filename.to_s if report_file.present?

    filename = "Looper Report : #{start_date} : #{end_date}"
    filename = "#{filename} : #{studios.size > 1 ? 'All' : studios.first.name}" if studios.present?
    filename = "#{filename} : #{platforms.size > 1 ? 'All' : platforms.first.name}" if platforms.present?
    filename = "#{filename} : #{territories.size > 1 ? 'All' : territories.first.name}" if territories.present?
    filename = "#{filename} : Medium ATF" if metadata[:atf] == 'mediumAtf'
    filename = "#{filename} : True ATF" if metadata[:atf] == 'trueAtf'
    filename = "#{filename} : #{metadata[:search]}" if metadata[:search].present?
    filename = "#{filename} : SOV Only" if report_type == 'csv_sov'
    filename = "#{filename} : Distributors Only" if report_type == 'csv_distributors'
    extension = report_type == 'xlsx' ? 'xlsx' : 'csv'
    "#{filename.gsub(%r{^.*(\\|/)}, '').gsub(/[^0-9A-Za-z.\-\s:]/, '_').strip}.#{extension}"
  end

  def process_now(host:)
    return if status == 'cancelled'

    if report_type == 'xlsx'
      Exporter::XlsxExporterService.new(report: self, host:).perform
    else
      Exporter::CsvExporterService.new(report: self, host:).perform
    end
  end

  def process_later(host:)
    return if status == 'cancelled'

    ExportReportJob.perform_later(report_id: id, host:)
  end

  def cancel!
    update(status: 'cancelled') if %w[queued in_progress].include?(status)
  end

  def platforms
    return @platforms if @platforms.present?

    @platforms = organization.platforms
    @platforms = @platforms.where(code: metadata[:platform]) if metadata[:platform].present?
    @platforms
  end

  def territories
    return @territories if @territories.present?

    @territories = organization.territories
    @territories = @territories.where(iso_code: metadata[:territory]) if metadata[:territory].present?
    @territories
  end

  def filtered_spots
    return @filtered_spots if @filtered_spots.present?

    @filtered_spots = Spot.includes(section: { page: { scan: { device: %i[platform territory] } } })
                          .joins(:publications, section: { page: :scan })
                          .joins(
                            "INNER JOIN organizations_scans ON organizations_scans.scan_id = scans.id AND \
                            organizations_scans.organization_id = #{organization.id}"
                          )
                          .where(scans: { scan_date: period })

    @filtered_spots = if metadata[:sort_by].present?
                        order = metadata[:sort_by][0] == '-' ? 'DESC' : 'ASC'
                        metadata[:sort_by].slice!(0) if order == 'DESC'
                        valid_columns = Spot.column_names.include?(metadata[:sort_by])
                        @filtered_spots.order("spots.#{metadata[:sort_by]} #{order}") if valid_columns
                      else
                        @filtered_spots.order(:scraped_at)
                      end

    @filtered_spots.distinct
  end

  def spots
    return @spots if @spots.present?

    studios_join = if metadata[:studio].present?
                     metadata[:studio] = metadata[:studio].split(',').map(&:to_i) if metadata[:studio].is_a?(String)
                     " AND publications.studio_id IN (#{metadata[:studio]})"
                   end
    @spots = filtered_spots.joins(
      "INNER JOIN competitors_organizations ON (publications.studio_id = #{organization.studio_id || 'NULL'}\
      #{studios_join}) OR (publications.studio_id = competitors_organizations.studio_id AND \
      publications.territory_id = competitors_organizations.territory_id AND \
      competitors_organizations.organization_id = #{organization.id}#{studios_join})"
    )
    @spots = @spots.where(territories: { iso_code: metadata[:territory] }) if metadata[:territory].present?
    @spots = @spots.where(platforms: { code: metadata[:platform] }) if metadata[:platform].present?
    @spots = @spots.where(medium_atf: true) if metadata[:atf] == 'medium_atf'
    @spots = @spots.where(true_atf: true) if metadata[:atf] == 'true_atf'
    @spots = @spots.search(metadata[:search]).with_pg_search_rank if metadata[:search].present?
    @spots.distinct.with_attached_screenshot
  end

  def spots_by_studio
    @spots_by_studio ||= spots.where(publications: { studio_id: studio_ids })
  end

  def scans
    return @scans if @scans.present?

    @scans = organization.scans.where(scan_date: period)
    if metadata[:territory].present?
      @scans = @scans.joins(device: :territory).where(territories: { iso_code: metadata[:territory] })
    end
    if metadata[:platform].present?
      @scans = @scans.joins(device: :platform).where(platforms: { code: metadata[:platform] })
    end
    @scans
  end

  def mpv_total
    scans.sum(&:mpv_total)
  end

  def mpv_total_for(studio:)
    scans.sum { |s| s.mpv_total_for(studio:) }
  end

  def metadata
    self[:metadata]&.with_indifferent_access
  end

  def weeks
    # each week starts Sun 00:00:00 and ends Sat 23:59:59
    start_day = start_date
    report_weeks = start_date.upto(end_date).each_with_object([]) do |day, weeks|
      if day.wday == WEEKDAY_END
        weeks << (start_day.beginning_of_day..day.end_of_day)
        start_day = day + 1.day
      end
      weeks
    end
    report_weeks << (start_day.beginning_of_day..end_date.end_of_day) unless end_date.wday == WEEKDAY_END
    report_weeks
  end

  def studios
    return @studios if @studios.present?

    @studios = accessible_studios
    @studios = @studios.where(id: metadata[:studio]&.to_s&.split(',')) if metadata[:studio].present?
    @studios
  end

  def studio_ids
    @studio_ids ||= studios.pluck(:id)
  end

  def competitors
    return @competitors if @competitors.present?

    @competitors = organization.competitors_organizations
    if metadata[:studio].present?
      @competitors = @competitors.joins(:studio).where(studios: { id: metadata[:studio]&.to_s&.split(',') })
    end

    if metadata[:territory].present?
      @competitors = @competitors.joins(:territory).where(territories: { iso_code: metadata[:territory] })
    end

    return if @competitors.blank?

    @competitors = @competitors.pluck(:studio_id,
                                      :territory_id).each_with_object({}) do |(studio_id, territory_id), obj|
      obj[territory_id] ||= []
      obj[territory_id] << studio_id
    end
  end

  private

  def period
    return (start_date..end_date) if start_date.present?

    metadata[:date].present? ? Date.parse(metadata[:date]) : Time.zone.today
  end

  def start_date
    return Date.parse(metadata[:date].first) if metadata[:date].is_a?(Array)

    Date.parse(metadata[:start_date]) if metadata[:start_date].present?
  end

  def end_date
    return Date.parse(metadata[:date].last) if metadata[:date].is_a?(Array)
    return Date.parse(metadata[:end_date]) if metadata[:end_date].present?

    start_date + 7.days if start_date.present?
  end

  def pending_count_validation
    pending_count = organization.reports.pending.size
    errors.add(:base, 'cannot schedule more than two reports at once.') if pending_count >= 2
  end
end
