require 'sinatra'
require 'sinatra/cross_origin'
require 'sinatra/json'
require 'aws-sdk'
require 'json'
require 'csv'

configure do
  enable :cross_origin
end

configure :development do
  require 'pry'
  set :allow_origin, 'http://localhost:3333'
end

configure :production do
  set :allow_origin, 'http://adler-staging.s3.amazonaws.com'
end

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

    columns = attendees.collect(&:keys).flatten.uniq
    default_attendee = columns.each_with_object({}) {|column, hash| hash[column] = ''}

    csv_string = CSV.generate do |csv|
      csv << columns

      attendees.each do |attendee|
        csv << default_attendee.merge(attendee).values
      end
    end

    obj = bucket.objects[file_key_path(file_name)]
    obj.write(csv_string, acl: 'authenticated_read', content_disposition: "attachment; filename=#{file_name}")

    response = {
      success: true,
      location: obj.url_for(:read).to_s
    }
  else
    response = {
      success: false,
      message: 'no data'
    }
  end

  json response
end
