require 'sinatra'
require 'twitter'
require 'geokit'
require './lib/place'

Geokit::default_units = :kms
Geokit::default_formula = :sphere

average_cycling_speed_mph = 5
start_date = Time.new(2012,4,10)

configure :production do
  Twitter.configure do |config|                        
    config.endpoint = 'http://' + ENV['APIGEE_TWITTER_API_ENDPOINT']     
    config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
    config.oauth_token = ENV['TWITTER_OAUTH_TOKEN']
    config.oauth_token_secret = ENV['TWITTER_OAUTH_TOKEN_SECRET']
  end
end

get '/' do
  tweets = Twitter.user_timeline("patforna")
  @last_tweet = tweets.select { |x| !x.text.include? '#whereispat' }.first
  @past_locations = Array.new()
  
  tweets.each {|tweet|
    place = Place.parse(tweet)
   
    # if the tweet has geo data and is after the start date... let's track it! 
    if  place != Place::TIMBUKTU && (tweet.created_at <=> start_date) == 1
      @past_locations.push({:place => place, :lat => place.latitude, :long => place.longitude, :time => tweet.created_at, :text => tweet.text })
    end
  }
  
  @past_locations.reverse!
  
  previous_location = @past_locations[0];
  first_location = @past_locations[0];
  first_LL = Geokit::LatLng.new(first_location[:lat],first_location[:long])
  
  @distance_time_speeds = @past_locations.drop(1).map {|location|
    previous_LL = Geokit::LatLng.new(previous_location[:lat],previous_location[:long])
    current_LL = Geokit::LatLng.new(location[:lat],location[:long])
    distance = previous_LL.distance_to(current_LL)
    culmulative_distance = first_LL.distance_to(current_LL)
    
    time_between_locations = ((location[:time] - previous_location[:time]) / 3600).round(2)
    culmulative_time = ((location[:time] - first_location[:time]) / 3600).round(2)
    
    speed = (distance / time_between_locations.to_f).round(2)
    
    previous_location = location
    @total_distance = culmulative_distance
    @total_time = culmulative_time
    {:distance_in_kilometers => distance,:culmulative_distance_in_kilometers => culmulative_distance, :culmulative_time_in_hours => culmulative_time, :time_diff_in_hours => time_between_locations, :speed_in_kph => speed}
  }

  @hours_since_last_tweet = ((Time.new() - @last_tweet.created_at) / 3600).round
  @how_far_might_he_have_gone = @hours_since_last_tweet * average_cycling_speed_mph

  @last_place = @past_locations.last[:place]
  @time_at_location = @past_locations.last[:time] 

  erb :index
end
