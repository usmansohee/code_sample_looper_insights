# frozen_string_literal: true

class ScanSerializer
  attr_accessor :organization, :scans, :studio_ids

  WEEKDAY_START = 0 # Sunday
  WEEKDAY_END = 6 # Saturday

  def initialize(organization, scans, studio_ids)
    @organization = organization
    @scans = scans
    @studio_ids = studio_ids
  end

  def weekly_summary(params, platforms, territories)
    start_date = start_date(params)
    end_date = end_date(params)
    studios = Studio.find(studio_ids)
    studios.each_with_object({}) do |studio, summary|
      summary[:start_date] ||= start_date
      summary[:end_date] ||= end_date
      platforms.each do |platform|
        summary[platform.id] ||= { platform_id: platform.id, platform_code: platform.code }
        territories.each do |territory|
          next unless organization.studio_id == studio.id || organization.competitors_organizations.find_by(
            studio_id: studio.id, territory_id: territory.id
          )

          summary[platform.id][territory.id] ||= { territory_id: territory.id, territory_iso_code: territory.iso_code }
          studio_scans = summary[platform.id][territory.id][:scans] ||= scans.select(
            :id, :saved_statistics, :scan_date, :device_id, :updated_at
          ).joins(:device)
           .where(devices: { platform_id: platform.id, territory_id: territory.id })

          spots_count = summary[platform.id][territory.id][:spots_count] ||= studio_scans.sum do |scan|
            studio_ids.sum { |s| scan.spots_count_for(Studio.new(id: s)) }
          end

          next unless spots_count.positive?

          all_spots_count = summary[platform.id][territory.id][:all_spots_count] ||= studio_scans.sum(&:spots_count)
          matf_spots_count = summary[platform.id][territory.id][:matf_spots_count] ||=
            studio_scans.sum(&:medium_atf_spots_count)
          tatf_spots_count = summary[platform.id][territory.id][:tatf_spots_count] ||=
            studio_scans.sum(&:true_atf_spots_count)
          total_mpv = summary[platform.id][territory.id][:total_mpv] ||= studio_scans.sum(&:mpv_total)

          summary[platform.id][territory.id][studio.id] ||= { studio_id: studio.id, studio_name: studio.name }
          studio_spots_count = summary[platform.id][territory.id][studio.id][:studio_spots_count] ||=
            studio_scans.sum do |scan|
              scan.spots_count_for(studio)
            end
          matf_spots_count = summary[platform.id][territory.id][studio.id][:matf_spots_count] ||=
            studio_scans.sum do |scan|
              scan.medium_atf_spots_count_for(studio)
            end
          tatf_spots_count = summary[platform.id][territory.id][studio.id][:tatf_spots_count] ||=
            studio_scans.sum do |scan|
              scan.true_atf_spots_count_for(studio)
            end
          studio_mpv = summary[platform.id][territory.id][studio.id][:studio_mpv] ||=
            studio_scans.sum do |s|
              s.mpv_total_for(studio)
            end

          if studio_spots_count.positive?
            summary[platform.id][territory.id][studio.id][:sov] ||= studio_spots_count.to_f / all_spots_count
          end
          if matf_spots_count.positive?
            summary[platform.id][territory.id][studio.id][:matf_sov] ||=
              matf_spots_count.to_f / matf_spots_count
          end
          if tatf_spots_count.positive?
            summary[platform.id][territory.id][studio.id][:tatf_sov] ||=
              tatf_spots_count.to_f / tatf_spots_count
          end

          summary[platform.id][territory.id][studio.id][:share_of_mpv] ||= studio_mpv / total_mpv if total_mpv.positive?

          summary[platform.id][territory.id][:weekly] ||= []
          weeks(start_date, end_date).each_with_index do |week, i|
            week_start_date = week.first
            week_end_date = week.last
            summary[platform.id][territory.id][:weekly][i] ||= {}
            summary[platform.id][territory.id][:weekly][i][:start_date] ||= week_start_date
            summary[platform.id][territory.id][:weekly][i][:end_date] ||= week_end_date

            week_scans = summary[platform.id][territory.id][:weekly][i][:scans] ||= studio_scans.select do |scan|
              week.cover?(scan.scan_date)
            end
            summary[platform.id][territory.id][:weekly][i][:spots_count] ||= week_scans.sum do |scan|
              studio_ids.sum { |s| scan.spots_count_for(Studio.new(id: s)) }
            end
            week_spots_count = summary[platform.id][territory.id][:weekly][i][:spots_count]
            next unless week_spots_count.positive?

            all_week_spots_count = summary[platform.id][territory.id][:weekly][i][:all_spots_count] ||=
              week_scans.sum(&:spots_count)
            matf_spots_count = summary[platform.id][territory.id][:weekly][i][:matf_spots_count] ||=
              week_scans.sum(&:medium_atf_spots_count)
            tatf_spots_count = summary[platform.id][territory.id][:weekly][i][:tatf_spots_count] ||=
              week_scans.sum(&:true_atf_spots_count)
            total_mpv = summary[platform.id][territory.id][:weekly][i][:mpv_total] ||=
              week_scans.sum(&:mpv_total)

            summary[platform.id][territory.id][:weekly][i][studio.id] ||= {
              studio_id: studio.id, studio_name: studio.name
            }
            summary[platform.id][territory.id][:weekly][i][studio.id][:studio_spots_count] ||=
              week_scans.sum do |scan|
                scan.spots_count_for(studio)
              end
            studio_spots_count = summary[platform.id][territory.id][:weekly][i][studio.id][:studio_spots_count]
            summary[platform.id][territory.id][:weekly][i][studio.id][:matf_spots_count] ||=
              week_scans.sum do |scan|
                scan.medium_atf_spots_count_for(studio)
              end
            matf_spots_count = summary[platform.id][territory.id][:weekly][i][studio.id][:matf_spots_count]
            summary[platform.id][territory.id][:weekly][i][studio.id][:tatf_spots_count] ||=
              week_scans.sum do |scan|
                scan.true_atf_spots_count_for(studio)
              end
            tatf_spots_count = summary[platform.id][territory.id][:weekly][i][studio.id][:tatf_spots_count]
            studio_mpv = summary[platform.id][territory.id][:weekly][i][studio.id][:studio_mpv] ||=
              week_scans.sum do |s|
                s.mpv_total_for(studio)
              end

            if studio_spots_count.positive?
              summary[platform.id][territory.id][:weekly][i][studio.id][:sov] ||=
                studio_spots_count.to_f / all_week_spots_count
            end
            if matf_spots_count.positive?
              summary[platform.id][territory.id][:weekly][i][studio.id][:matf_sov] ||=
                matf_spots_count.to_f / matf_spots_count
            end
            if tatf_spots_count.positive?
              summary[platform.id][territory.id][:weekly][i][studio.id][:tatf_sov] ||=
                tatf_spots_count.to_f / tatf_spots_count
            end
            if total_mpv.positive?
              summary[platform.id][territory.id][:weekly][i][studio.id][:share_of_mpv] ||=
                studio_mpv / total_mpv
            end
          end
        end
      end
    end
  end

  def summary(include_titles: [])
    scans.map do |scan|
      previous_scan = scan.previous

      if studio_ids
        accessible_studio_ids = organization.competitors_organizations.where(territory_id: scan.territory.id)
            .pluck(:studio_id)
        accessible_studio_ids << organization.studio_id
        studios = Studio.find(studio_ids & scan.studio_ids & accessible_studio_ids)
        studios_summary = studios.map do |studio|
          {
            id: studio.id,
            name: studio.name,
            total_spots: scan.spots_count_for(studio),
            medium_atf_spots: scan.medium_atf_spots_count_for(studio),
            true_atf_spots: scan.true_atf_spots_count_for(studio),
            share_of_voice: scan.share_of_voice_for(studio),
            previous_total_spots: previous_scan&.spots_count_for(studio),
            previous_medium_atf_spots: previous_scan&.medium_atf_spots_count_for(studio),
            previous_true_atf_spots: previous_scan&.true_atf_spots_count_for(studio),
            previous_share_of_voice: previous_scan&.share_of_voice_for(studio),
            mpv_total: scan.mpv_total_for(studio),
            previous_mpv_total: previous_scan&.mpv_total_for(studio)
          }
        end
      end

      titles_summary = include_titles.map do |title|
        {
          id: title.id,
          name: title.name,
          total_spots: scan.spots_count_for(title),
          medium_atf_spots: scan.medium_atf_spots_count_for(title),
          true_atf_spots: scan.true_atf_spots_count_for(title),
          share_of_voice: scan.share_of_voice_for(title),
          previous_total_spots: previous_scan&.spots_count_for(title),
          previous_medium_atf_spots: previous_scan&.medium_atf_spots_count_for(title),
          previous_true_atf_spots: previous_scan&.true_atf_spots_count_for(title),
          previous_share_of_voice: previous_scan&.share_of_voice_for(title),
          mpv_total: scan.mpv_total_for(title),
          previous_mpv_total: previous_scan&.mpv_total_for(title)
        }
      end.compact

      serialized_scan = {
        id: scan.id,
        scan_date: scan.scan_date.to_s,
        medium_atf_spots: scan.medium_atf_spots_count,
        true_atf_spots: scan.true_atf_spots_count,
        total_spots: scan.spots_count,
        previous_scan_id: previous_scan&.id,
        previous_scan_date: previous_scan&.scan_date&.to_s,
        previous_medium_atf_spots: previous_scan&.medium_atf_spots_count,
        previous_true_atf_spots: previous_scan&.true_atf_spots_count,
        previous_total_spots: previous_scan&.spots_count,
        territory: {
          id: scan.territory.id,
          name: scan.territory.name,
          iso_code: scan.territory.iso_code
        },
        platform: {
          id: scan.platform.id,
          name: scan.platform.name,
          code: scan.platform.code
        },
        mpv_total: scan.mpv_total,
        previous_mpv_total: previous_scan&.mpv_total,
        studios: studios_summary,
        device: scan.device
      }

      serialized_scan.merge!(titles: titles_summary) if titles_summary.present?

      unless ActiveRecord::Base.connected_to?(role: :reading)
        scan.save if scan.changed?
        previous_scan.save if previous_scan&.changed?
      end

      serialized_scan
    end
  end

  private

  def start_date(params)
    return Date.parse(params[:dates].first) if params[:dates].is_a?(Array)

    Date.parse(params[:start_date]) if params[:start_date].present?
  end

  def end_date(params)
    return Date.parse(params[:dates].last) if params[:dates].is_a?(Array)
    return Date.parse(params[:end_date]) if params[:end_date].present?

    start_date(params) + 7.days if start_date(params).present?
  end

  def weeks(start_date, end_date)
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
end
