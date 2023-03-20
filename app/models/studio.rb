# frozen_string_literal: true

# == Schema Information
#
# Table name: studios
#
#  id                   :bigint           not null, primary key
#  distributor_type     :string           default("app")
#  gradient_color_end   :string
#  gradient_color_start :string
#  name                 :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_studios_on_name  (name) UNIQUE
#
class Studio < ApplicationRecord
  has_one_attached :logo
  has_one_attached :alternate_logo
  has_many :competitors_organizations, dependent: :destroy
  has_many :organizations, dependent: :nullify
  has_many :publications, dependent: :destroy
  has_many :insights, dependent: :nullify
  has_many :titles, -> { distinct }, through: :publications
  has_and_belongs_to_many :territories
  validates :name, presence: true, uniqueness: true
  validates :distributor_type, presence: true
  accepts_nested_attributes_for :territories, allow_destroy: true

  def self.find_or_create_by_normalized_name(name, distributor_type)
    studio = where(
      "lower(regexp_replace(name, ' ', '', 'g')) = ? and distributor_type = ?", name.downcase.gsub(/\s*/, ''),
      distributor_type
    ).first
    return studio.reload if studio

    create(name:, distributor_type:)
  end

  def as_json(options = {})
    options.merge!(methods: %i[logo_url alternate_logo_url]) unless options.key?(:methods)
    super(options.merge(include: %i[territories]))
  end

  def logo_url
    Rails.application.routes.url_helpers.url_for(logo) if logo.present?
  end

  def alternate_logo_url
    Rails.application.routes.url_helpers.url_for(alternate_logo) if alternate_logo.present?
  end
end
