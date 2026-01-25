class MarkdownsController < ApplicationController
  include MarkdownHelper

  protect_from_forgery with: :exception

  def preview
    html = markdown_to_html(params[:text].to_s)
    render html: html.html_safe, layout: false
  end
end
