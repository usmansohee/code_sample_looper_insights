# frozen_string_literal: true

class InsightsController < ApplicationController
  before_action :admin_authorized, only: %i[create update destroy]

  def index
    insights = current_organization.insights.filter_by(filter_params)

    render json: { insights: }
  end

  def create
    insight = Insight.new(insight_params)
    if insight.save
      insight.image.attach(params[:image]) if params[:image].present?

      render json: { insights: insight }
    else
      render json: { error: insight.errors.messages }, status: :unprocessable_entity
    end
  end

  def update
    insight = Insight.find(params[:id])
    if insight.update(insight_params)
      insight.image.attach(params[:image]) if params[:image].present?

      render json: { insight: }
    else
      render json: { error: insight.errors.messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Insight.find(params[:id]).destroy
  end

  private

  def filter_params
    params.permit(:date, :kind, :platform, :territory)
  end

  def insight_params
    (params[:insight] || params).permit(:title, :headline, :body, :icon, :icon_color, :highlighted_at, :kind, :change,
                                        :image_url, :author, :author_role, :studio_id, :owner_organization_id, :scan_id,
                                        :status, devices_insights_attributes: %i[id device_id image _destroy])
  end
end
