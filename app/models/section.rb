# frozen_string_literal: true

# == Schema Information
#
# Table name: sections
#
#  id          :bigint           not null, primary key
#  name        :string
#  position    :integer
#  spots_count :integer
#  subtitle    :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  page_id     :integer          not null
#
# Indexes
#
#  index_sections_on_page_id  (page_id)
#
# Foreign Keys
#
#  fk_rails_...  (page_id => pages.id) ON DELETE => cascade
#
class Section < ApplicationRecord
  belongs_to :page
  has_many :spots, dependent: :destroy

  def spots_count
    return self['spots_count'] if self['spots_count'].present?

    count = spots.count
    update(spots_count: count) unless ActiveRecord::Base.connected_to?(role: :reading)
    count
  end
end
