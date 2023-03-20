# frozen_string_literal: true

# == Schema Information
#
# Table name: publications_spots
#
#  id             :bigint           not null, primary key
#  publication_id :integer
#  spot_id        :integer
#
# Indexes
#
#  index_publications_spots_on_publication_id              (publication_id)
#  index_publications_spots_on_publication_id_and_spot_id  (publication_id,spot_id) UNIQUE
#  index_publications_spots_on_spot_id                     (spot_id)
#
class PublicationsSpot < ApplicationRecord
  belongs_to :publication
  belongs_to :spot
end
