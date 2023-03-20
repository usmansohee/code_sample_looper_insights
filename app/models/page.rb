# frozen_string_literal: true

# == Schema Information
#
# Table name: pages
#
#  id                  :bigint           not null, primary key
#  name                :string
#  platform_identifier :string
#  scraped_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  scan_id             :integer          not null
#
# Indexes
#
#  index_pages_on_scan_id  (scan_id)
#
# Foreign Keys
#
#  fk_rails_...  (scan_id => scans.id)
#
class Page < ApplicationRecord
  belongs_to :scan
  has_many :sections, dependent: :destroy
  has_many :spots, through: :sections

  def atf_conditions
    atf = scan.tatf_rules
    return unless atf

    atf.where(page_name: platform_identifier)
  end
end
