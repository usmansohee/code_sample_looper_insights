# frozen_string_literal: true

# == Schema Information
#
# Table name: competitors_organizations
#
#  id              :bigint           not null, primary key
#  organization_id :integer
#  studio_id       :integer
#  territory_id    :bigint
#
# Indexes
#
#  competitors_organizations_unique                    (studio_id,organization_id,territory_id) UNIQUE
#  index_competitors_organizations_on_organization_id  (organization_id)
#  index_competitors_organizations_on_studio_id        (studio_id)
#  index_competitors_organizations_on_territory_id     (territory_id)
#
class CompetitorsOrganization < ApplicationRecord
  belongs_to :organization
  belongs_to :studio
  belongs_to :territory
end
