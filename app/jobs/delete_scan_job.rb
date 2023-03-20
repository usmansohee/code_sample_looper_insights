# frozen_string_literal: true

class DeleteScanJob < ApplicationJob
  queue_as :default

  def perform(url:)
    headers = {}

    headers['x-api-key'] = ENV.fetch('SCAN_API_KEY') if url.match(/api\..*\.looperinsights\.com/)

    json = faraday_client.get(url, nil, headers).body
    Importer::DataImporterService.new(json, :delete).perform
  end
end
