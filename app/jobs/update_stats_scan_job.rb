# frozen_string_literal: true

class UpdateStatsScanJob < ApplicationJob
  sidekiq_options queue: :stats_scan, retry: 1

  def perform(id:)
    scan = Scan.find(id)
    scan.calculate_saved_statistics!
    notify_slack(scan)
  end

  def notify_slack(scan)
    SlackClient.send_success "Scan stats recalculated successfully for scan ##{scan.id}"
  end
end
