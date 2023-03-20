# frozen_string_literal: true

class ApplicationController < ActionController::API
  require 'net/http'

  include CognitoTokenVerifier::ControllerMacros
  include Pagy::Backend

  after_action { pagy_headers_merge(@pagy) if @pagy }
  before_action :set_default_host_url
  before_action :set_paper_trail_whodunnit
  skip_before_action :verify_cognito_token, if: :api_authenticated?

  private

  def pagy_get_vars(collection, vars)
    vars[:count] ||= faster_count(collection)
    vars[:page]  ||= params[vars[:page_param] || Pagy::DEFAULT[:page_param]]
    vars
  end

  def faster_count(collection)
    collection.reorder('').count(:all)
  end

  def set_paper_trail_whodunnit
    whodunnit = if api_authenticated?
                  "apiKey:#{request.headers['Authorization']}"
                elsif request.headers['Authorization'].present? && cognito_token
                  "cognitoUser:#{cognito_token.decoded_token['sub']}"
                end

    PaperTrail.request.whodunnit = whodunnit || 'unauthenticated'
  end

  def set_default_host_url
    Rails.application.routes.default_url_options[:host] = request.base_url
  end

  def current_organization
    return Organization.find_by(name: 'Looper Insights') if api_authenticated?
    return unless request.headers['Authorization'].present? && cognito_token.decoded_token

    @current_organization ||= Organization.find_by(id: cognito_groups)
  end

  def cognito_groups
    Rails.logger.debug cognito_token.decoded_token.inspect
    @cognito_groups ||= cognito_token.decoded_token['cognito:groups']&.select { |g| g.split(':')[0].size < 36 }
  end

  def admin_logged_in?
    return true if api_authenticated?

    cognito_groups.any? { |g| g.split(':')[0] == '0' }
  end

  def admin_authorized
    render json: { message: 'Please log in with an admin account' }, status: :unauthorized unless admin_logged_in?
  end

  def api_authenticated?
    ENV['ANALYTICS_API_KEY'].present? && ENV.fetch('ANALYTICS_API_KEY', nil) == request.headers['Authorization']
  end

  def handle_expired_token(exception)
    render json: { message: exception }, status: :unauthorized
  end

  def handle_invalid_token(exception)
    render json: { message: exception }, status: :unauthorized
  end
end
