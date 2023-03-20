# frozen_string_literal: true

class TitleSerializer
  attr_accessor :titles, :current_organization, :platform, :territory

  def initialize(titles, current_organization: nil, territory: nil, platform: nil)
    @titles = titles
    @territory = territory
    @platform = platform
    @current_organization = current_organization
  end

  def with_similar_titles
    titles.map { |title| title_attributes_with_similar_titles(title) }
  end

  private

  def title_attributes(title)
    {
      id: title.id,
      name: title.name,
      year: title.year,
      metadata: title.metadata,
      artworks: title.artworks.map { |a| a.as_json(methods: %i[image_url territory_code]) }
    }
  end

  def title_attributes_with_similar_titles(title)
    attributes = title_attributes(title)
    attributes.merge(similar_titles: title.similar_titles.map { |t| title_attributes_with_similar_titles(t) })
  end
end
