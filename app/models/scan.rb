# frozen_string_literal: true

# == Schema Information
#
# Table name: scans
#
#  id               :bigint           not null, primary key
#  finished_at      :datetime
#  saved_statistics :jsonb            not null
#  scan_date        :date
#  scraper          :string
#  started_at       :datetime
#  url              :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  device_id        :integer
#
# Indexes
#
#  index_scans_on_device_id           (device_id)
#  index_scans_on_scan_date           (scan_date)
#  index_scans_on_started_at_as_date  (((started_at)::date))
#
class Scan < ApplicationRecord
  belongs_to :device
  has_many :insights, dependent: :nullify
  has_many :pages, dependent: :destroy
  has_many :sections, through: :pages
  has_many :spots, through: :sections
  has_many :titles, through: :spots

  delegate :platform, :territory, :platform_id, :territory_id, :tatf_rules, to: :device

  scope :with_studio, (lambda do
    joins(:device, pages: { sections: { spots: :publications } })
      .where('publications.territory_id = devices.territory_id')
      .distinct
  end)

  scope :search, (lambda do |search_params|
    scans = self
    if search_params[:studio_ids].present?
      scans = scans.with_studio.where('publications.studio_id': search_params[:studio_ids])
    end
    if search_params[:platform_codes].present?
      scans = scans.joins(device: :platform).where(platform: { code: search_params[:platform_codes] })
    end
    if search_params[:territory_iso_codes].present?
      scans = scans.joins(device: :territory).where(territory: { iso_code: search_params[:territory_iso_codes] })
    end
    scans = scans.where(scan_date: search_params[:dates]) if search_params[:dates].present?
    scans = scans.where(scan_date: search_params[:start_date]..) if search_params[:start_date].present?
    scans = scans.where(scan_date: ..search_params[:end_date]) if search_params[:end_date].present?
    scans
  end)

  def previous
    @previous ||= siblings.where(scan_date: scan_date - 1.week).last ||
                  siblings.where(scan_date: scan_date - 6.days).last ||
                  siblings.where(scan_date: scan_date - 8.days).last ||
                  siblings.where(scan_date: scan_date - 2.weeks).last ||
                  siblings.where('scan_date < ?', scan_date).last
  end

  def medium_atf_spots_count(calculate: false)
    statistics_column = 'medium_atf_spots'
    saved_statistics[statistics_column] = spots.where(medium_atf: true).count if calculate

    saved_statistics[statistics_column] || medium_atf_spots_count(calculate: true)
  end

  def true_atf_spots_count(calculate: false)
    statistics_column = 'true_atf_spots'
    saved_statistics[statistics_column] = spots.where(true_atf: true).count if calculate

    saved_statistics[statistics_column] || true_atf_spots_count(calculate: true)
  end

  def spots_count(calculate: false)
    statistics_column = 'spots_count'
    saved_statistics[statistics_column] = spots.count || 0 if calculate

    saved_statistics[statistics_column] || spots_count(calculate: true)
  end

  def mpv_total(calculate: false)
    statistics_column = 'mpv_total'
    saved_statistics[statistics_column] = spots.sum(&:mpv).to_f if calculate

    saved_statistics[statistics_column]&.to_f || mpv_total(calculate: true)
  end

  def statistic_for(object, statistic:, calculate: false, &block)
    statistics_key = object.class.to_s.downcase
    saved_statistics[statistics_key] ||= {}

    if calculate
      value = yield(spots_for(object)) unless statistics_key == 'studio' && studio_ids.exclude?(object.id)

      saved_statistics[statistics_key][object.id.to_s] ||= {}
      saved_statistics[statistics_key][object.id.to_s][statistic] = value || 0
    end

    statistics_field = saved_statistics[statistics_key][object.id.to_s]
    statistics_field&.fetch(statistic, nil) || statistic_for(object, statistic:, calculate: true, &block)
  end

  def medium_atf_spots_count_for(object, calculate: false)
    statistic_for(object, statistic: 'medium_atf_spots', calculate:) do |spots_for_object|
      spots_for_object.where(medium_atf: true).count
    end
  end

  def true_atf_spots_count_for(object, calculate: false)
    statistic_for(object, statistic: 'true_atf_spots', calculate:) do |spots_for_object|
      spots_for_object.where(true_atf: true).count
    end
  end

  def share_of_voice_for(object, calculate: false)
    statistic_for(object, statistic: 'share_of_voice', calculate:) do |spots_for_object|
      spots_for_object.count / spots_count.to_f
    end
  end

  def mpv_total_for(object, calculate: false)
    statistic_for(object, statistic: 'mpv_total', calculate:) do |spots_for_object|
      spots_for_object.sum(&:mpv).to_f
    end
  end

  def spots_count_for(object, calculate: false)
    statistic_for(object, statistic: 'spots_count', calculate:, &:count)
  end

  def spots_for(object)
    case object
    when Studio
      spots.distinct.joins(:publications).where(publications: { studio_id: object.id, territory_id: territory.id })
    when Title
      spots.distinct.where(title_id: object.id)
    else
      raise 'Object must be a `Studio` or a `Title`.'
    end
  end

  def studio_ids
    Publication.select('DISTINCT studio_id').where(title: titles).where(territory_id:).map(&:studio_id)
  end

  def studios
    Studio.find(studio_ids)
  end

  def calculate_saved_statistics
    studios.each do |studio|
      medium_atf_spots_count_for(studio, calculate: true)
      true_atf_spots_count_for(studio, calculate: true)
      share_of_voice_for(studio, calculate: true)
      mpv_total_for(studio, calculate: true)
      spots_count_for(studio, calculate: true)
    end

    titles.each do |title|
      medium_atf_spots_count_for(title, calculate: true)
      true_atf_spots_count_for(title, calculate: true)
      share_of_voice_for(title, calculate: true)
      mpv_total_for(title, calculate: true)
      spots_count_for(title, calculate: true)
    end

    medium_atf_spots_count(calculate: true)
    true_atf_spots_count(calculate: true)
    mpv_total(calculate: true)
    spots_count(calculate: true)
  end

  def calculate_saved_statistics!
    calculate_saved_statistics
    save
  end

  private

  def siblings
    @siblings ||= Scan.where(device:)
  end
end
