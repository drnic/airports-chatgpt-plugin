require "sinatra"
require "csv"
require "json"

class Airport
  attr_reader :name, :ident, :latitude_deg, :longitude_deg, :wikipedia_link

  def initialize(row)
    @name = row["name"]
    @ident = row["ident"]
    @latitude_deg = row["latitude_deg"]
    @longitude_deg = row["longitude_deg"]
    @wikipedia_link = row["wikipedia_link"]
  end

  def to_json(options = {})
    {
      name: name,
      ident: ident,
      lat: latitude_deg,
      long: longitude_deg,
      url: wikipedia_link
    }.to_json
  end
end

def load_airports_from_csv(file)
  airports = []

  CSV.foreach(file, headers: true, col_sep: ",") do |row|
    airports << Airport.new(row)
  end

  airports
end

def airports
  @airports ||= load_airports_from_csv("data/au-airports.csv")
end

def find_nearest_airports(lat, long, count)
  airports.sort_by { |a| Math.sqrt((a.latitude_deg.to_f - lat)**2 + (a.longitude_deg.to_f - long)**2) }.first(count)
end

def search_airports_by_name(city_name)
  airports.select { |a| a.name.downcase.include?(city_name.downcase) }
end

def search_airports_by_ident(ident)
  airports.select { |a| a.ident.downcase.include?(ident.downcase) }
end

get "/nearestAirports" do
  content_type :json

  lat = params[:lat].to_f
  long = params[:long].to_f
  count = (params[:count] || 1).to_i

  find_nearest_airports(lat, long, count).to_json
end

get "/searchByName" do
  content_type :json

  city_name = params[:cityName]
  search_airports_by_name(city_name).to_json
end

get "/searchByIdent" do
  content_type :json

  ident = params[:ident]
  search_airports_by_ident(ident).to_json
end

get "/.well-known/ai-plugin.json" do
  content_type "application/json"

  @ai_plugin_file ||= begin
    domain = request.host

    file_path = File.join(settings.root, ".well-known", "ai-plugin.json")
    # Load file, replace domain, and send it back
    file = File.read(file_path)
    file.gsub!(/DOMAIN/, domain)
    file
  end
end

get "/.well-known/openapi.yaml" do
  content_type "application/yaml"

  @openapi_file ||= begin
    domain = request.host

    file_path = File.join(settings.root, ".well-known", "openapi.yaml")
    # Load file, replace domain, and send it back
    file = File.read(file_path)
    file.gsub!(/DOMAIN/, domain)
    file
  end
end

# Serve files from the .well-known folder
get "/.well-known/*" do
  filename = params[:splat].first
  file_path = File.join(settings.root, ".well-known", filename)

  if File.exist?(file_path)
    send_file file_path
  else
    status 404
    "File not found #{file_path}"
  end
end
