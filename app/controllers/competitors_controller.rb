# frozen_string_literal: true

class CompetitorsController < ApplicationController
  def index
    render json: { competitors: current_organization.competitors_json }
  end
end
