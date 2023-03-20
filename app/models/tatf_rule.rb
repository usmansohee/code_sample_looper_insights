# frozen_string_literal: true

# == Schema Information
#
# Table name: tatf_rules
#
#  id           :bigint           not null, primary key
#  column_end   :integer
#  column_start :integer
#  page_name    :string
#  row          :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  device_id    :bigint
#
# Indexes
#
#  index_tatf_rules_on_device_id  (device_id)
#
class TatfRule < ApplicationRecord
  belongs_to :device
  validates :page_name, :row, :column_start, :column_end, presence: true

  before_destroy :recalculate_removed_atf
  after_save :recalculate_related_atf

  def recalculate_related_atf
    RecalculateAtfJob.perform_later(id:)
  end

  def recalculate_removed_atf
    spots.update_all(true_atf: false)
    recalculate_scan_stats!
  end

  def row_spots
    @row_spots ||= Spot.joins(section: { page: :scan })
                       .where(
                         sections: { position: row },
                         pages: { platform_identifier: page_name },
                         scans: { device_id: }
                       )
  end

  def spots
    row_spots.where(position: column_start..column_end)
  end

  def other_spots
    row_spots.where.not(position: column_start..column_end)
  end

  def recalculate_scan_stats!
    row_spots.pluck('scans.id').uniq.each do |scan_id|
      UpdateStatsScanJob.perform_later(id: scan_id)
    end
  end
end
