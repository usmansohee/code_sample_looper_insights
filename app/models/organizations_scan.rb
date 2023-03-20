# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations_scans
#
#  organization_id :integer
#  scan_id         :bigint
#
class OrganizationsScan < ApplicationRecord
  belongs_to :organization
  belongs_to :scan
end
