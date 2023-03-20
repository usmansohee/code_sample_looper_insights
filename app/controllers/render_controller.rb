# frozen_string_literal: true

class RenderController < ApplicationController
  include ActionView::Rendering

  private

  def render_to_body(options)
    _render_to_body_with_renderer(options) || super
  end
end
