# frozen_string_literal: true

# == Schema Information
#
# Table name: platforms
#
#  id         :bigint           not null, primary key
#  code       :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_platforms_on_code  (code) UNIQUE
#  index_platforms_on_name  (name) UNIQUE
#
class Platform < ApplicationRecord
  has_many :devices, dependent: :destroy
  has_many :scans, through: :devices
  has_many :organizations, -> { distinct }, through: :devices
  has_many :tatf_rules, through: :devices

  validates :name, :code, presence: true, uniqueness: true
end
