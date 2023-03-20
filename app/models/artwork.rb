# frozen_string_literal: true

# == Schema Information
#
# Table name: artworks
#
#  id           :bigint           not null, primary key
#  binary_phash :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  territory_id :integer          not null
#  title_id     :integer          not null
#
# Indexes
#
#  index_artworks_on_binary_phash_and_territory_id  (binary_phash,territory_id) UNIQUE
#  index_artworks_on_territory_id                   (territory_id)
#  index_artworks_on_title_id                       (title_id)
#
# Foreign Keys
#
#  fk_rails_...  (territory_id => territories.id)
#  fk_rails_...  (title_id => titles.id)
#
class Artwork < ApplicationRecord
  belongs_to :title, optional: true
  belongs_to :territory

  has_one_attached :thumbnail
  has_many :spots, dependent: :nullify

  validates :binary_phash, presence: true, uniqueness: { scope: :territory_id }, length: { is: 64 }
  validates :thumbnail, presence: true
  validates :title, presence: true, if: -> { title_id.present? }

  after_save :replace_title_in_spots

  delegate :iso_code, to: :territory, prefix: true

  alias_attribute :territory_code, :territory_iso_code

  def self.convert_phash(phash)
    return if phash.blank?

    # if Binary, return with 64 bits
    return phash.rjust(64, '0') if phash.match(/^[01]+$/)

    # if not Binary, assume HEX phash and convert
    return phash.to_i(16).to_fs(2).rjust(64, '0') if phash.size == 16

    phash
  end

  def image=(image)
    thumbnail.attach(image) if image.present?
  end

  def image_url=(image_url)
    thumbnail.attach(io: URI.parse(image_url).open, filename: 'artwork.png') if image_url.present?
  end

  def image_url
    Rails.application.routes.url_helpers.url_for(thumbnail) if thumbnail.present?
  end

  def territory_code=(territory_code)
    self.territory = Territory.find_by(iso_code: territory_code)
  end

  private

  def replace_title_in_spots
    return if title.blank?

    spots.where.not(title_id:).update_all(title_id:)
  end
end
