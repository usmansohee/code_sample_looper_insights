# frozen_string_literal: true

# == Schema Information
#
# Table name: insights
#
#  id                    :bigint           not null, primary key
#  author                :string
#  author_role           :string
#  body                  :text
#  change                :string
#  headline              :string
#  highlighted_at        :date
#  kind                  :string
#  status                :string           default("published"), not null
#  title                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  owner_organization_id :bigint
#  scan_id               :integer
#  studio_id             :integer
#
# Indexes
#
#  index_insights_on_kind                   (kind)
#  index_insights_on_owner_organization_id  (owner_organization_id)
#  index_insights_on_scan_id                (scan_id)
#  index_insights_on_status                 (status)
#  index_insights_on_studio_id              (studio_id)
#
class Insight < ApplicationRecord
  KINDS = %w[merchandising competitor insight recommendation].freeze
  STATUSES = %w[draft published deleted].freeze

  has_one_attached :image
  belongs_to :studio
  belongs_to :owner_organization, class_name: 'Organization', optional: true
  belongs_to :scan, optional: true
  has_many :devices_insights, dependent: :destroy
  has_many :devices, -> { distinct }, through: :devices_insights
  validates :title, :highlighted_at, presence: true
  validates :kind, presence: true, inclusion: KINDS
  validates :status, presence: true, inclusion: STATUSES

  accepts_nested_attributes_for :devices_insights, allow_destroy: true

  def as_json(options = {})
    super(options.merge(methods: :image_url,
                        include: [{ devices_insights: { methods: :image_url },
                                    devices: { include: %i[territory platform] } }]))
  end

  def image_url
    Rails.application.routes.url_helpers.url_for(image) if image.present?
  end

  def self.for_organization(organization)
    where(owner_organization: organization).or(
      where(owner_organization: nil, studio: organization.studio).where.not(kind: 'competitor').or(
        where(owner_organization: nil, studio: organization.competitors)
      )
    )
  end

  def self.filter_by(params)
    insights = all

    if params[:date].present?
      date = Date.parse(params[:date])
      insights = where(highlighted_at: date.all_day)
    end

    insights = insights.where(kind: params[:kind].split(',')) if params[:kind].present?
    insights = insights.where(status: params[:status].presence&.split(',') || 'published')

    if params[:platform].present?
      insights = insights.joins(devices: :platform).where(platforms: { code: params[:platform] })
    end

    if params[:territory].present?
      insights = insights.joins(devices: :territory).where(territories: { iso_code: params[:territory] })
    end

    insights
  end
end
