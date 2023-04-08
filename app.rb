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

def generate_flight_plan_link(coordinates)
  # Convert the coordinates to the format expected by the SkyVector URL
  formatted_coords = coordinates.map do |coord|
    lat = coord["lat"]
    long = coord["long"]

    # Convert decimal latitude to degrees, minutes, and seconds
    lat_degrees = lat.abs.to_i
    lat_minutes_decimal = (lat.abs - lat_degrees) * 60
    lat_minutes = lat_minutes_decimal.to_i
    lat_seconds = ((lat_minutes_decimal - lat_minutes) * 60).round
    lat_formatted = format("%02d%02d%02d", lat_degrees, lat_minutes, lat_seconds)

    # Convert decimal longitude to degrees, minutes, and seconds
    long_degrees = long.abs.to_i
    long_minutes_decimal = (long.abs - long_degrees) * 60
    long_minutes = long_minutes_decimal.to_i
    long_seconds = ((long_minutes_decimal - long_minutes) * 60).round
    long_formatted = format("%03d%02d%02d", long_degrees, long_minutes, long_seconds)

    # Determine the direction for latitude (N or S) based on the sign of the value
    lat_dir = (lat >= 0) ? "N" : "S"
    # Determine the direction for longitude (E or W) based on the sign of the value
    long_dir = (long >= 0) ? "E" : "W"

    # Combine degrees, minutes, seconds, and direction to form the final coordinate string
    "#{lat_formatted}#{lat_dir}#{long_formatted}#{long_dir}"
  end.join("%20")

  # Generate the SkyVector URL with the formatted coordinates
  "https://skyvector.com/?fpl=#{formatted_coords}"
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

post "/flightPlan" do
  # Parse the request body as JSON
  request_data = JSON.parse(request.body.read)

  # Validate that the 'coordinates' key is present in the request data
  unless request_data.key?("coordinates")
    status 400
    return {error: "Invalid input provided. Missing coordinates."}.to_json
  end

  # Extract the coordinates from the request data
  coordinates = request_data["coordinates"]

  # Validate that the coordinates are an array
  unless coordinates.is_a?(Array)
    status 400
    return {error: "Invalid input provided. Coordinates must be an array."}.to_json
  end

  # Generate the flight plan link based on the coordinates
  flight_plan_link = generate_flight_plan_link(coordinates)

  # Return the flight plan link as a JSON response
  {flightPlanLink: flight_plan_link}.to_json
rescue JSON::ParserError
  # Handle JSON parsing errors
  status 400
  {error: "Invalid JSON input provided."}.to_json
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
