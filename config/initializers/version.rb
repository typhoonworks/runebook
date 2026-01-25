module Runebook
  VERSION = begin
    path = Rails.root.join("VERSION")
    File.exist?(path) ? File.read(path).strip.freeze : "0.0.0-dev".freeze
  end
end
