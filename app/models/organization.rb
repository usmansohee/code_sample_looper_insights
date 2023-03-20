# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations
#
#  id                   :bigint           not null, primary key
#  core_enabled         :boolean          default(FALSE)
#  dashboard_enabled    :boolean          default(TRUE)
#  gradient_color_end   :string
#  gradient_color_start :string
#  name                 :string
#  start_date           :date
#  studio_id            :integer
#
# Indexes
#
#  index_organizations_on_name       (name) UNIQUE
#  index_organizations_on_studio_id  (studio_id)
#
class Organization < ApplicationRecord
  has_one_attached :logo
  belongs_to :studio, optional: true
  has_many :competitors_organizations, dependent: :destroy
  has_many :competitors, -> { distinct }, through: :competitors_organizations, source: :studio
  has_many :organizations_scans, dependent: nil
  has_many :scans, through: :organizations_scans
  has_many :reports, dependent: :destroy
  has_many :organizations_scan_dates, dependent: :destroy
  has_many :devices_organizations, dependent: :destroy
  has_many :devices, through: :devices_organizations, dependent: :destroy
  has_many :platforms, -> { distinct }, through: :devices
  has_many :territories, -> { distinct }, through: :devices
  validates :name, presence: true, uniqueness: true
  validates :studio, presence: { message: 'is invalid' }, if: -> { studio_id.present? }
  accepts_nested_attributes_for :organizations_scan_dates, allow_destroy: true

  def as_json(options = {})
    json = super(options.merge(methods: :logo_url,
                               include: [
                                 { studio: { include: %i[territories], methods: %i[logo_url alternate_logo_url] },
                                   devices: { include: %i[territory platform] } },
                                 :organizations_scan_dates
                               ]))
    json[:competitors] = competitors_json
    json
  end

  def competitors_json
    competitors.order(:name).includes(competitors_organizations: :territory).map do |competitor|
      competitor.as_json.except('territories').merge(
        territories: competitor.competitors_organizations.where(organization_id: id).map(&:territory).as_json
      )
    end
  end

  def logo_image=(image)
    logo.attach(image) if image.present?
  end

  def logo_url=(image_url)
    logo.attach(io: URI.parse(image_url).open, filename: 'logo.png') if image_url.present?
  end

  def logo_url
    Rails.application.routes.url_helpers.url_for(logo) if logo.present?
  end

  def insights
    Insight.for_organization(self)
  end

  def accessible_studios
    Studio.where(id: [studio, *competitors])
  end
end
