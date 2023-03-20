# frozen_string_literal: true

class TatfRulesController < ApplicationController
  def create
    tatf_rule = TatfRule.new(tatf_rule_params)

    if tatf_rule.save
      render json: tatf_rule
    else
      render json: { errors: tatf_rule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    tatf_rule = TatfRule.find(params[:id])

    if tatf_rule.update(tatf_rule_params)
      render json: tatf_rule
    else
      render json: { errors: tatf_rule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    tatf_rule = TatfRule.find(params[:id])
    render json: tatf_rule.destroy
  end

  private

  def tatf_rule_params
    params.permit(:device_id, :page_name, :row, :column_start, :column_end)
  end
end
