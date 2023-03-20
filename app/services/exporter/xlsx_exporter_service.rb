# frozen_string_literal: true

module Exporter
  class XlsxExporterService < Base
    def perform
      return if report.reload.status == 'cancelled'

      report.update(started_at: Time.zone.now, status: 'in_progress')

      FileUtils.mkdir(report_path) unless Dir.exist?(report_path)

      generate_xlsx!

      report.report_file.attach(
        io: File.open(report_file),
        filename: report.report_filename,
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )

      report.update(finished_at: Time.zone.now, status: 'completed') if report.reload.status != 'cancelled'
    rescue StandardError => e
      failures = report.metadata[:failures] || []
      failures << { time: Time.zone.now, error: e.inspect }
      report.update(
        finished_at: Time.zone.now,
        status: 'failed',
        metadata: report.metadata.deep_merge({ failures: })
      )
      raise
    ensure
      %w[report sov distributors].each do |file|
        file = File.join(report_path, "#{file}_#{report.id}.xlsx")
        File.delete(file) if File.exist?(file)
      end
    end

    private

    def report_file
      File.join(report_path, "report_#{report.id}.xlsx")
    end

    def generate_xlsx!
      workbook = FastExcel.open(report_file, constant_memory: true)

      generate_sov_sheet!(workbook) unless report.report_type == 'xlsx_distributors'
      generate_distributor_sheets!(workbook) unless report.report_type == 'xlsx_sov'

      workbook.close
    end

    def generate_sov_sheet!(workbook)
      bold = workbook.bold_format
      percent = workbook.number_format('0.00%')

      sheet = workbook.add_worksheet('Share of Voice')
      sheet.set_column 3, 3, FastExcel::DEF_COL_WIDTH, bold
      sheet.set_column 4, 4, FastExcel::DEF_COL_WIDTH, percent
      sheet.set_column 8, 8, FastExcel::DEF_COL_WIDTH, percent
      sheet.set_column 11, 11, FastExcel::DEF_COL_WIDTH, percent
      sheet.set_column 14, 14, FastExcel::DEF_COL_WIDTH, percent
      sheet.auto_width = true
      sheet.append_row(sov_columns, bold)

      row_index = 2
      @report.studios.each do |studio|
        @report.platforms.each do |platform|
          @report.territories.each do |territory|
            next unless report.organization.competitors_organizations.find_by(studio:, territory:) ||
                        report.organization.studio == studio

            scans = @report.scans
                            .select(:id, :saved_statistics, :scan_date, :device_id, :updated_at)
                            .joins(:device)
                            .where(devices: { platform_id: platform.id, territory_id: territory.id })

            spots_count = scans.sum do |scan|
              @report.studio_ids.sum { |s| scan.spots_count_for(Studio.new(id: s)) }
            end

            next unless spots_count.positive?

            all_spots_count = scans.sum(&:spots_count)
            studio_spots_count = scans.sum { |scan| scan.spots_count_for(studio) }
            matf_spots_count = scans.sum(&:medium_atf_spots_count)
            matf_studio_spots_count = scans.sum { |scan| scan.medium_atf_spots_count_for(studio) }
            tatf_spots_count = scans.sum(&:true_atf_spots_count)
            tatf_studio_spots_count = scans.sum { |scan| scan.true_atf_spots_count_for(studio) }
            total_mpv = scans.sum(&:mpv_total)
            studio_mpv = scans.sum { |s| s.mpv_total_for(studio) }

            sov = studio_spots_count.to_f / all_spots_count if studio_spots_count.positive?
            matf_sov = matf_studio_spots_count.to_f / matf_spots_count if matf_studio_spots_count.positive?
            tatf_sov = tatf_studio_spots_count.to_f / tatf_spots_count if tatf_studio_spots_count.positive?
            share_of_mpv = studio_mpv / total_mpv if total_mpv.positive?

            sheet.append_row ['', studio.name, platform.name, territory.name,
                              share_of_mpv, total_mpv,
                              studio_spots_count, all_spots_count, sov,
                              matf_studio_spots_count, matf_spots_count, matf_sov,
                              tatf_studio_spots_count, tatf_spots_count, tatf_sov]

            row_index += 1

            next unless @report.weeks.size > 1

            @report.weeks.each do |week|
              date = "From #{week.first.strftime('%e %b %y')} to #{week.last.strftime('%e %b %y')}"

              week_scans = scans.select { |scan| week.cover?(scan.scan_date) }
              week_spots_count = week_scans.sum do |scan|
                @report.studio_ids.sum { |s| scan.spots_count_for(Studio.new(id: s)) }
              end
              next unless week_spots_count.positive?

              all_week_spots_count = week_scans.sum(&:spots_count)
              studio_spots_count = week_scans.sum { |scan| scan.spots_count_for(studio) }
              matf_spots_count = week_scans.sum(&:medium_atf_spots_count)
              matf_studio_spots_count = week_scans.sum { |scan| scan.medium_atf_spots_count_for(studio) }
              tatf_spots_count = week_scans.sum(&:true_atf_spots_count)
              tatf_studio_spots_count = week_scans.sum { |scan| scan.true_atf_spots_count_for(studio) }
              total_mpv = week_scans.sum(&:mpv_total)
              studio_mpv = week_scans.sum { |s| s.mpv_total_for(studio) }

              sov = studio_spots_count.to_f / all_week_spots_count if studio_spots_count.positive?
              matf_sov = matf_studio_spots_count.to_f / matf_spots_count if matf_studio_spots_count.positive?
              tatf_sov = tatf_studio_spots_count.to_f / tatf_spots_count if tatf_studio_spots_count.positive?
              share_of_mpv = studio_mpv / total_mpv if total_mpv.positive?

              sheet.append_row [date, studio.name, platform.name, territory.name,
                                share_of_mpv, total_mpv,
                                studio_spots_count, all_spots_count, sov,
                                matf_studio_spots_count, matf_spots_count, matf_sov,
                                tatf_studio_spots_count, tatf_spots_count, tatf_sov]

              row_index += 1
            end
          end
        end
      end
    end

    def generate_distributor_sheets!(workbook)
      bold = workbook.bold_format
      columns = ['Scan Date', 'Title', 'Platform', 'Region', 'Page Name', 'Number of Spots in Section',
                 'Row', 'Column', 'Medium ATF', 'True ATF', 'MPV', 'Screenshot']

      @report.studios.each do |studio|
        sheet = workbook.add_worksheet(studio.name)
        sheet.auto_width = true
        sheet.append_row(columns, bold)
        @report.spots
              .with_attached_screenshot
              .joins(:publications)
              .includes(section: { page: { scan: { device: %i[territory platform] } } })
              .select(
                :id,
                :name,
                :position,
                :medium_atf,
                :section_id,
                :title_id,
                :true_atf,
                :mpv,
                :updated_at,
                'scans.scan_date'
              )
              .where(publications: { studio_id: studio.id })
              .find_each do |s|
          screenshot_url = s.screenshot.present? ? Rails.application.routes.url_helpers.url_for(s.screenshot) : nil
          sheet.append_row [I18n.l(s.scan.scan_date), s.name, s.platform.name, s.territory.name,
                            [s.page.name, s.section.name].join(' / '), s.section.spots_count, s.row, s.column,
                            (s.medium_atf ? 1 : 0), (s.true_atf ? 1 : 0), s.mpv, FastExcel::URL.new(screenshot_url)]
        end
      end
    end
  end
end
