# frozen_string_literal: true

# == Schema Information
#
# Table name: device_organizations_scan_dates
#
#  id                      :bigint           not null, primary key
#  end_date                :date
#  scan_days               :integer
#  start_date              :date
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  devices_organization_id :bigint
#
# Indexes
#
#  devices_organization_id  (devices_organization_id)
#
class DeviceOrganizationsScanDate < ApplicationRecord
  belongs_to :devices_organization
end
