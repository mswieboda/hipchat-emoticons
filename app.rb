# By Henrik Nyh <henrik@nyh.se> 2011-07-27 under the MIT license.
# See README.

# Load requirements.

require "rubygems"
require "bundler"
Bundler.require :default, (ENV['RACK_ENV'] || "development").to_sym


# Sass on Heroku.
# https://devcenter.heroku.com/articles/using-sass
# http://autonomousmachine.com/posts/2011/5/18/sass-and-sinatra-on-heroku

require "sass/plugin/rack"
use Sass::Plugin::Rack

use Rack::Static,
  urls: ['/stylesheets/'],
  root: "tmp"

Sass::Plugin.options.merge!(
  template_location: '.',
  css_location: 'tmp/stylesheets'
)

# Configure.

set :haml, format: :html5, attr_wrapper: %{"}

# Control.

get '/' do
  # Cache in Varnish: http://devcenter.heroku.com/articles/http-caching
  headers 'Cache-Control' => 'public, max-age=3600'

  @file       = EmoticonFile.new("./emoticons.json")
  @emoticons  = @file.emoticons(params[:order])
  @emoticons_custom = @emoticons.select{ |x| x.custom == true }
  @all_emoticons = @emoticons
  @updated_at = @file.updated_at
  haml :index
end

helpers do
  def partial(template, locals={})
    haml :"_#{template}", {}, locals
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end
end


# Models.

require "set"

class EmoticonFile

  BY_RECENT = "recent"

  def initialize(file, opts={})
    @file = file
  end

  def emoticons(order=nil)
    es = json.map { |e| Emoticon.new(e) }

    # The file can have duplicates, e.g. ":)" and ":-)". Only keep the first.
    known_paths = Set.new
    uniques = []
    es.each do |e|
      uniques << e unless known_paths.include?(e.path)
      known_paths << e.path
    end

    if order == BY_RECENT
      uniques.reverse
    else  # Alphabetical.
      uniques.sort_by { |x| x.shortcut }
    end
  end

  def updated_at
    File.mtime(@file)
  end

  private

  def json
    raw = File.read(@file)
    json = JSON.parse(raw)
  end

end

class Emoticon
  include Comparable
  attr_reader :shortcut, :path, :width, :height, :custom

  BASE_URL = "https://dujrsrsgsd3nh.cloudfront.net/img/emoticons/"

  def initialize(data)
    @path     = data["image"]
    @width    = data["width"].to_i
    @height   = data["height"].to_i
    @shortcut = data["shortcut"]
    @custom   = data["custom"]
  end

  def url
    File.join(base_url, @path)
  end

  private

  def base_url
    BASE_URL
  end
end
