# frozen_string_literal: true

# == Schema Information
#
# Table name: devices_insights
#
#  id         :bigint           not null, primary key
#  device_id  :integer
#  insight_id :integer
#
# Indexes
#
#  index_devices_insights_on_device_id                 (device_id)
#  index_devices_insights_on_device_id_and_insight_id  (device_id,insight_id) UNIQUE
#  index_devices_insights_on_insight_id                (insight_id)
#
class DevicesInsight < ApplicationRecord
  belongs_to :device
  belongs_to :insight

  has_one_attached :image

  # validates :device_id, uniqueness: { scope: :insight_id }

  def image_url
    Rails.application.routes.url_helpers.url_for(image) if image.present?
  end
end
