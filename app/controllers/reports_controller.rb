# frozen_string_literal: true

class ReportsController < RenderController
  def index
    report = Report.new organization: current_organization, metadata: report_params

    @pagy, spots = pagy report.spots

    serialized_spots = SpotSerializer.new(spots, current_organization.studio, report.competitors)
    render json: serialized_spots.as_json
  end

  private

  def report_params
    params.permit(:date, :start_date, :end_date, :platform, :territory, :atf,
                  :studio, :studio_ids, :search, :sort_by, date: [])
  end
end
