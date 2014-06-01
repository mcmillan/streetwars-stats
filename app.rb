require 'bundler'
Bundler.require
Dotenv.load

set :server, 'webrick'

# Pulls stats from the (probably not meant to be public) StreetWars API
# Will stop doing this if the commanders get angry with us
# Hope we don't get disqualified (it's not malicious!)
# TODO: Implement caching so we don't nail their Heroku dynos
def kill_counts
  stats = HTTParty.get('http://www.streetwars.net/api/games/1/stats')
  stats = stats.parsed_response
  {
    total: stats['assassins_count'],
    alive: stats['assassins_alive_count'],
    dead: stats['kills_count']
  }
end

# Pulls public tweets about StreetWars... there's a staggering number of people
# talking about how they "just got their assignment, OH WOW" so this will
# expose them. I should probably be in this list as I'm publishing this code
# in a public GitHub repo under my own name. Fucktard.
# TODO: Implement caching so Twitter don't rate limit us
def fucktards
  twitter_client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  twitter_client.search('streetwars OR @shadowgov -#4BangersProduction +exclude:retweets')
end

get '/' do
  haml :index, kill_counts: kill_counts, fucktards: fucktards
end
