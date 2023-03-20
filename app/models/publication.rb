# frozen_string_literal: true

# == Schema Information
#
# Table name: publications
#
#  id               :bigint           not null, primary key
#  distributor_type :string           default("studio"), not null
#  favourite        :boolean          default(FALSE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  studio_id        :integer          not null
#  territory_id     :integer          not null
#  title_id         :integer          not null
#
# Indexes
#
#  index_publications_on_distributor_type  (distributor_type)
#  index_publications_on_studio_id         (studio_id)
#  index_publications_on_territory_id      (territory_id)
#  index_publications_on_title_id          (title_id)
#
# Foreign Keys
#
#  fk_rails_...  (studio_id => studios.id)
#  fk_rails_...  (territory_id => territories.id)
#  fk_rails_...  (title_id => titles.id)
#
class Publication < ApplicationRecord
  belongs_to :territory
  belongs_to :title
  belongs_to :studio
  has_and_belongs_to_many :spots, -> { distinct }

  validate :favourite_validation

  def favourite_validation
    return unless favourite

    favourite = Publication.exists?(title_id:, territory_id:, favourite: true)
    errors.add(:base, 'cannot add more than one favourite studio for the given title per territory') if favourite
  end
end
