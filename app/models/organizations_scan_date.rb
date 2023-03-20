# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations_scan_dates
#
#  id              :bigint           not null, primary key
#  end_date        :date
#  scan_days       :integer
#  start_date      :date
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :bigint
#
# Indexes
#
#  index_organizations_scan_dates_on_organization_id  (organization_id)
#
class OrganizationsScanDate < ApplicationRecord
  belongs_to :organization
end
