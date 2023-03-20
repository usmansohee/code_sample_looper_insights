# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :admin_authorized

  def index
    versions = PaperTrail::Version.where(item_type: params[:type].classify, item_id: params[:id].classify)

    render json: versions
  end
end
