# frozen_string_literal: true

class ImportScanJob < ApplicationJob
  queue_as :scan_import

  def perform(url:, type: 'json', date: Time.zone.today)
    case type
    when 'json'
      headers = {}
      headers['x-api-key'] = ENV.fetch('SCAN_API_KEY') if stb?(url)

      json = send_request(url, headers).body
      scan_url = JSON.parse(json)['scan']['url']
      headers['x-api-key'] ||= ENV.fetch('SCAN_API_KEY') if stb?(scan_url)

      Importer::DataImporterService.new(json).perform
      send_confirmation(scan_url, headers) if headers['x-api-key'].present?
    when 'xlsx'
      Importer::XlsxImporterService.new(url, date).perform
    end
  rescue StandardError => e
    send_failure(scan_url, headers, e.message) if headers['x-api-key'].present?
  end

  private

  def send_request(uri, headers)
    faraday_client.get(uri, nil, headers)
  end

  def send_confirmation(uri, headers)
    faraday_client.put("#{uri}/confirm", nil, headers)
  end

  def send_failure(uri, headers, failure_message)
    faraday_client.post("#{uri}/failed", { status_message: failure_message }.to_json, headers)
  end

  def stb?(url)
    url.match(/api\..*\.looperinsights\.com/)
  end
end
