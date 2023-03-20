# frozen_string_literal: true

class ReportDatesSerializer
  attr_accessor :spots

  def initialize(spots)
    @spots = spots
  end

  def as_json
    dates = []
    spots.map do |spot|
      dates.push(spot.scraped_at.to_fs(:iso8601))
    end
    dates.uniq
  end
end
