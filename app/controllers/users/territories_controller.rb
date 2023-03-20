# frozen_string_literal: true

module Users
  class TerritoriesController < ApplicationController
    def index
      render json: { territories: current_organization.territories }
    end
  end
end
