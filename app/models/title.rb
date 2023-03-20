# frozen_string_literal: true

# == Schema Information
#
# Table name: titles
#
#  id               :bigint           not null, primary key
#  metadata         :jsonb
#  name             :string
#  year             :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  similar_title_id :integer
#
# Indexes
#
#  index_titles_on_lower_name               (lower((name)::text))
#  index_titles_on_lowercase_name_and_year  (lower((name)::text), year) UNIQUE
#  index_titles_on_name                     (name) USING gin
#  index_titles_on_similar_title_id         (similar_title_id)
#
class Title < ApplicationRecord
  has_many :artworks, dependent: :destroy
  has_many :publications, dependent: :destroy
  has_many :spots, dependent: :restrict_with_error
  has_many :studios, -> { distinct }, through: :publications
  has_many :territories, -> { distinct }, through: :publications
  has_many :similar_titles, class_name: 'Title',
                            foreign_key: 'similar_title_id',
                            dependent: :nullify,
                            inverse_of: :similar_title
  belongs_to :similar_title, class_name: 'Title', optional: true

  validates :name, uniqueness: { scope: :year, case_sensitive: false }

  include PgSearch::Model
  pg_search_scope :search,
                  against: :name,
                  using: {
                    trigram: {
                      threshold: 0.5,
                      word_similarity: true
                    }
                  }

  def self.find_or_create_with_metadata(name:, scraper:, platform:, metadata: {}, year: nil)
    title = if name
              Title.where('lower(name) = ?', name.downcase)
            else
              Title.where(name:)
            end
    title = title.where(year:).first

    formatted_metadata = {
      scraper => {
        platform => {
          title: name,
          year:
        }.merge(metadata)
      }
    }

    title&.metadata ||= {}
    title&.update(metadata: title.metadata.deep_merge(formatted_metadata))

    return title if title

    create(name:, year:, metadata: formatted_metadata)
  end

  def as_json(options = {})
    super(options.merge(methods: :artwork_url))
  end

  def artwork_url
    artworks&.first&.image_url
  end

  def mark_as_similar(title_id:)
    title = Title.find(title_id)
    update(similar_title: title)
  end

  def merge_with(title_id:)
    return if title_id.to_i == id.to_i

    transaction do
      title = Title.find(title_id)

      title.metadata ||= {}
      self.metadata ||= {}
      title.metadata = title.metadata.deep_merge(metadata)
      artworks.update_all(title_id: title.id)

      title.artworks.where.not(id: title.artworks.group(:binary_phash, :territory_id).select('min(id)')).destroy_all

      publications.each do |publication|
        existing_publication = title.publications.find_by(territory: publication.territory, studio: publication.studio)

        if existing_publication.blank?
          publication.update!(title_id: title.id)
        else
          PublicationsSpot.where(publication_id: publication.id).find_each do |publication_spot|
            spot = publication_spot.spot
            if PublicationsSpot.find_by(spot:, publication: existing_publication)
              publication_spot.destroy!
            else
              publication_spot.update(publication: existing_publication)
            end
          end

          publication.destroy!
        end
      end

      spots.update_all(title_id: title.id)

      delete if title.save

      title
    end
  end
end
