# frozen_string_literal: true

# == Schema Information
#
# Table name: spots
#
#  id          :bigint           not null, primary key
#  description :text
#  medium_atf  :boolean
#  metadata    :jsonb
#  mpv         :decimal(6, 4)
#  name        :string
#  position    :integer
#  scraped_at  :datetime
#  true_atf    :boolean
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  artwork_id  :integer
#  section_id  :integer
#  title_id    :integer          not null
#
# Indexes
#
#  index_spots_on_artwork_id  (artwork_id)
#  index_spots_on_medium_atf  (medium_atf)
#  index_spots_on_name        (name) USING gin
#  index_spots_on_scraped_at  (scraped_at)
#  index_spots_on_section_id  (section_id)
#  index_spots_on_title_id    (title_id)
#  index_spots_on_true_atf    (true_atf)
#
# Foreign Keys
#
#  fk_rails_...  (section_id => sections.id) ON DELETE => cascade
#  fk_rails_...  (title_id => titles.id)
#
class Spot < ApplicationRecord
  has_one_attached :screenshot
  belongs_to :artwork, optional: true
  belongs_to :section
  belongs_to :title
  has_and_belongs_to_many :publications, -> { distinct }

  before_create :calculate_atf

  delegate :page, to: :section
  delegate :scan, :atf_conditions, to: :page
  delegate :territory, :platform, :device, :started_at, to: :scan
  delegate :position, to: :section, prefix: true

  alias_attribute :column, :position
  alias_attribute :row, :section_position

  include PgSearch::Model
  pg_search_scope :search,
                  against: :name,
                  using: {
                    trigram: {
                      threshold: 0.5,
                      word_similarity: true
                    }
                  }

  def studio
    @studio ||= publications.joins(:studio).find_by('studios.distributor_type = ?', 'studio')&.studio
  end

  def app
    @app ||= publications.joins(:studio).find_by('studios.distributor_type = ?', 'app')&.studio
  end

  def breadcrumbs
    [page.name&.split('/'), section.name&.split('/')].flatten.compact.map(&:squish).uniq
  end

  def mpv
    return self[:mpv] if self[:mpv].present?

    ActiveRecord::Base.connected_to(role: :writing) do
      calculated_mpv = Mpv::MpvCalculatorService.new(spot: self).calculated_mpv
      update(mpv: calculated_mpv)
      calculated_mpv
    end
  end

  private

  def calculate_atf
    self.medium_atf = row <= 10 && column <= 10

    return unless atf_conditions

    self.true_atf = !!true_atf_columns&.include?(column)
  end

  def true_atf_columns
    condition = atf_conditions.joins(device: :territory).find_by(row:, territory: { iso_code: territory.iso_code })

    return unless condition

    columns = condition.column_start..conditio n.column_end
    Array(columns) if columns
  end
end
