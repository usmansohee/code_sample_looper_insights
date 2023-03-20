# frozen_string_literal: true

class ExportsController < RenderController
  def index
    render json: { exports: current_organization.reports.order(id: :desc).limit(100) }
  end

  def create
    report = current_organization.reports.build(metadata: export_params)

    if report.save
      report.process_later(host: request.base_url)
      render json: { exports: report }
    else
      render json: { error: report.errors.messages }, status: :unprocessable_entity
    end
  end

  def show
    report = current_organization.reports.find(params[:id])

    if report.report_file.present?
      redirect_to report.report_file_url
    else
      render json: {}
    end
  end

  def cancel
    report = current_organization.reports.find(params[:export_id])

    if report.cancel!
      render json: { exports: report }
    else
      render json: { error: "cannot cancel report in #{report.status} status." }, status: :unprocessable_entity
    end
  end

  private

  def export_params
    params.permit(:date, :start_date, :end_date, :platform, :territory, :atf,
                  :studio, :studio_ids, :search, :report_type, date: [])
  end
end
