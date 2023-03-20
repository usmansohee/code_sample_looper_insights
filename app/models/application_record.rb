# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: {
    writing: :primary,
    reading: ActiveRecord::Base.configurations
                               .configs_for(env_name: Rails.env, include_hidden: true)
                               .find(&:replica?)
                               &.name
                               &.to_sym || :primary
  }

  has_paper_trail
end
