# frozen_string_literal: true

class RecalculateAtfJob < ApplicationJob
  sidekiq_options queue: :recalculate_atf, retry: 1

  def perform(id:)
    tatf_rule = TatfRule.find(id)
    tatf_rule.spots.update_all(true_atf: true)
    tatf_rule.other_spots.update_all(true_atf: false)
    tatf_rule.recalculate_scan_stats!
  end
end
