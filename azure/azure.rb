#! /usr/bin/env ruby

# See Azure API documentation:
# https://westus.dev.cognitive.microsoft.com/docs/services/5adf991815e1060e6355ad44/operations/56f91f2e778daf14a499e1fa
#
# API limitations:
# For images uploaded directly to the API images must be:
#  * In a supported image format: JPEG, PNG, GIF, BMP.
#  * Image file size must be less than 4MB.
#  * Image dimensions must be at least 50 x 50.

# Azure doesn't have an API library for Ruby (or much 
# of anything from what i can tell), so instead we're 
# going to use RestClient to interact with their REST API directly.
require 'rest-client'
require 'json'

def ocr(path)
  # We're just defaulting to the East US region.
  region = "eastus"
  # This is the REST endpoint we're going to communicate with.
  url = "https://#{region}.api.cognitive.microsoft.com/vision/v2.0/ocr"
  # Azure's other demos indicate that we can specify 
  # the language or set it to "unk".  We'll also have
  # it guess at the orientation, just in case our
  # documents are oriented in a direction other than up.
  payload = {
    data: File.open(path, 'rb'),
    language: 'unk',
    detectOrientation: 'true'
  }
  # In order to make the API actually accept a request
  # we'll need to read the credentials somewhere.
  # I'm reading it out of the ENV.
  headers = {
    'Ocp-Apim-Subscription-Key': ENV['AZURE_KEY'],
    'Content-Type': 'application/json'
  }
  puts "OCRing #{path}"
  # Send the request to Azure
  response = RestClient.post(url, payload, headers)
  data = JSON.parse(response.body)

  dirname = File.dirname(path)
  basename = File.basename(path, ".*")
  # Extract the text out of the response and write it into a file.
  File.open("#{dirname}/#{basename}.azure.txt", 'w'){ |f| f.puts parse_results(response.body) }
  # Write the raw JSON data out into a file.
  File.open("#{dirname}/#{basename}.azure.json", 'w'){ |f| f.puts response.body }
end

# Azure doesn't provide the text in an easily accesible way.
# In order to get the text, you have to unpeel the position
# data/containers to get down to the individual words.
def parse_results(data)
  # keys: ["language", "textAngle", "orientation", "regions"]
  data["regions"].map do |region|
    region["lines"].map do |line|
      line["words"].map do |word|
        word["text"]
      end.join(" ")
    end.join("\n")
  end
end

# Read the first 
arg_path = ARGV.first
File.directory?(arg_path)
paths = Dir.glob(File.join arg_path, '*.{png,jpg}')

puts "Annotating #{paths.count} images..."

wait_time = (paths.size > 20) ? 3 : 0

paths.each do |path|
  ocr(path)
  if wait_time > 0
    puts  "sleeping for #{wait_time} seconds"
    sleep wait_time
  end
end

def output_text(paths)
  paths.each do |path|
    dirname = File.dirname(path)
    basename = File.basename(path, ".*")
    data = JSON.parse(File.read(path))
    File.open("#{dirname}/#{basename}.txt", 'w'){ |f| f.puts parse_results(data) }
  end
end
