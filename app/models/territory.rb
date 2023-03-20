# frozen_string_literal: true

# == Schema Information
#
# Table name: territories
#
#  id         :bigint           not null, primary key
#  iso_code   :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_territories_on_iso_code  (iso_code) UNIQUE
#  index_territories_on_name      (name) UNIQUE
#
class Territory < ApplicationRecord
  has_many :devices, dependent: :destroy
  has_many :publications, dependent: :destroy
  has_many :scans, -> { distinct }, through: :devices
  has_many :organizations, -> { distinct }, through: :devices
  has_many :titles, -> { distinct }, through: :publications
  has_and_belongs_to_many :studios

  validates :name, presence: true, uniqueness: true
  validates :iso_code, presence: true, uniqueness: true
end
