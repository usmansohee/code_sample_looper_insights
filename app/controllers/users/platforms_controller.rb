# frozen_string_literal: true

module Users
  class PlatformsController < ApplicationController
    def index
      render json: { platforms: current_organization.platforms }
    end
  end
end
