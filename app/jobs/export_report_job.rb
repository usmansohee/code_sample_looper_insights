# frozen_string_literal: true

class ExportReportJob < ApplicationJob
  sidekiq_options queue: :bulk_export, retry: 1

  def perform(report_id:, host:)
    Report.find(report_id).process_now(host:)
  end
end
