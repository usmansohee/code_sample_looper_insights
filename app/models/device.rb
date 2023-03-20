# frozen_string_literal: true

# == Schema Information
#
# Table name: devices
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  platform_id  :integer
#  territory_id :integer
#
# Indexes
#
#  index_devices_on_platform_id                   (platform_id)
#  index_devices_on_platform_id_and_territory_id  (platform_id,territory_id) UNIQUE
#  index_devices_on_territory_id                  (territory_id)
#
class Device < ApplicationRecord
  belongs_to :territory
  belongs_to :platform
  has_many :scans, dependent: :nullify
  has_many :devices_insights, inverse_of: :device, dependent: :destroy
  has_many :insights, -> { distinct }, through: :devices_insights
  has_many :devices_organizations, dependent: :destroy
  has_many :organizations, through: :devices_organizations, dependent: :destroy
  has_many :tatf_rules, dependent: :destroy
  validates :territory_id, uniqueness: { scope: :platform_id }

  def as_json(options = {})
    super(options.merge(include: [:territory, :platform,
                                  { devices_organizations: { include: %i[device_organizations_scan_dates] } }]))
  end
end
