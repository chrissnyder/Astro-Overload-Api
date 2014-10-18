require 'sinatra'
require 'sinatra/cross_origin'
require 'aws-sdk'
require 'json'
require 'csv'
require 'pry'

configure do
  enable :cross_origin
end

set :allow_origin, 'http://localhost:3333'
set :allow_methods, [:post]

AWS.config({
  access_key_id: ENV['ADLER_AWS_ACCESS_KEY_ID'],
  secret_access_key: ENV['ADLER_AWS_SECRET_ACCESS_KEY']
})
s3 = AWS::S3.new
bucket = s3.buckets['adler-resources']

def file_key_path(file_name)
  "astro-overload/#{ file_name }"
end

post '/' do
  attendees = params[:attendees].values # bit silly
  event_name = params[:event_name]

  if attendees.length
    file_name = "#{ event_name } #{ Time.now }.csv".downcase.gsub(' ', '_')
    csv_string = CSV.generate do |csv|
      csv << attendees.first.keys

      attendees.each do |attendee|
        csv << attendee.values
      end
    end

    obj = bucket.objects[file_key_path(file_name)]
    obj.write(csv_string, acl: 'authenticated_read')

    response = [200, {
      success: true,
      location: obj.url_for(:read).to_s
    }.to_json]
  else
    response = [400, {
      success: false,
      message: 'no data'
    }.to_json]
  end

  response
end
