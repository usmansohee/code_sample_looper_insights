# frozen_string_literal: true

# == Schema Information
#
# Table name: devices_organizations
#
#  id              :bigint           not null, primary key
#  device_id       :integer
#  organization_id :integer
#
# Indexes
#
#  index_devices_organizations_on_device_id                      (device_id)
#  index_devices_organizations_on_device_id_and_organization_id  (device_id,organization_id) UNIQUE
#  index_devices_organizations_on_organization_id                (organization_id)
#
class DevicesOrganization < ApplicationRecord
  belongs_to :device
  belongs_to :organization
  has_many :device_organizations_scan_dates, dependent: :destroy

  accepts_nested_attributes_for :device_organizations_scan_dates, allow_destroy: true
end
