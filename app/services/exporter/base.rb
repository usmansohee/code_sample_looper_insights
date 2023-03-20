# frozen_string_literal: true

module Exporter
  class Base
    attr_accessor :report

    def initialize(report:, host:)
      @report = report
      Rails.application.routes.default_url_options[:host] = host
    end

    private

    def report_path
      Rails.root.join('tmp/reports')
    end

    def sov_columns
      ['Date', 'Distributor', 'Platform', 'Region',
       'Share of MPV', 'Total MPV', 'Total Number of Spots for Distributor',
       'Total Number of Spots in Platform', '% Share of Voice',
       'Total Number of Medium Range ATF Spots for Distributor',
       'Total Number of Medium Range ATF Spots in Platform',
       '% Medium Range ATF Spots',
       'Total Number of True ATF Spots for Distributor', 'Total Number of True ATF Spots in Platform',
       '% True ATF Spots']
    end
  end
end
