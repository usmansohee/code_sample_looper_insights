# frozen_string_literal: true

# This is the top-level record of a stb slack client.
module SlackClient
  class << self
    def send_message(message)
      return if notifier.blank?

      notifier.ping message
    end

    def send_error(message)
      send_message(":x: #{message}")
    end

    def send_success(message)
      send_message(":heavy_check_mark: #{message}")
    end

    def send_warning(message)
      send_message(":warning: #{message}")
    end

    private

    def slack_client_url
      @slack_client_url ||= ENV.fetch('SLACK_CLIENT_URL', nil)
    end

    def notifier
      @notifier ||= Slack::Notifier.new slack_client_url if slack_client_url.present?
    end
  end
end
