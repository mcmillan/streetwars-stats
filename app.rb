require 'bundler'
require 'json'
Bundler.require
Dotenv.load

# Use redis for a bit of simple caching
$redis = Redis.new(url: ENV['REDISTOGO_URL'])

class Assassin
  attr_accessor :name
  attr_accessor :team_leader
  attr_accessor :alive
  attr_accessor :kills
  attr_accessor :assassin_token
  attr_accessor :user_token
  attr_accessor :avatar

  def initialize(sw_assassin)
    self.name = sw_assassin[:user][:username].strip
    self.team_leader = sw_assassin[:is_team_leader]
    self.alive = sw_assassin[:is_alive]
    self.kills = sw_assassin[:kill_count]
    self.assassin_token = sw_assassin[:unique_token]
    self.user_token = sw_assassin[:user][:unique_token]
    self.avatar = sw_assassin[:user][:avatar] ? sw_assassin[:user][:avatar][:s3_medium] : 'http://s3.amazonaws.com/streetwars-dev/web/no_image_medium_tri.jpg'
  end

  def to_json(*args)
    {
      name: name,
      team_leader: team_leader,
      alive: alive,
      kills: kills,
      assassin_token: assassin_token,
      user_token: user_token,
      avatar: avatar
    }.to_json(*args)
  end
end

class Team
  attr_accessor :name
  attr_accessor :assassins
  attr_accessor :token

  def initialize(sw_team)
    self.name = sw_team[:display_name]
    self.token = sw_team[:unique_token]
    self.assassins = []
    sw_team[:registered_assassins].each do |a|
      self.assassins << Assassin.new(a)
    end
  end

  def team_leader
    assassins.find(&:team_leader) || assassins.first
  end

  def kills
    assassins.map(&:kills).reduce(&:+)
  end

  def size
    assassins.count
  end

  def alive
    assassins.select(&:alive).count
  end

  def dead
    size - alive
  end

  def solo?
    size <= 1
  end

  def ensemble?
    !solo?
  end

  def competing?
    dead != size && team_leader.alive
  end

  def lethality
    return 0 if size <= 0

    kills.to_f / size.to_f
  end

  def to_json(*args)
    {
      name: name.downcase == 'solo agent' ? team_leader.name : name,
      token: token,
      kills: kills,
      alive: alive,
      dead: dead,
      size: size,
      solo: solo?,
      competing: competing?,
      lethality: lethality,
      assassins: assassins
    }.to_json(*args)
  end
end

def game
  return JSON.parse($redis[:game], symbolize_names: true) if $redis[:game]

  game = HTTParty.get('http://www.streetwars.net/api/games/1').parsed_response.to_json

  $redis[:game] = game
  $redis.expire(:game, 600)

  JSON.parse($redis[:game], symbolize_names: true)
end

def stats
  teams = game[:public_registered_teams]

  teams.map! { |t| Team.new(t) }
  teams.sort! do |a, b|
    if a.lethality > b.lethality
      -1
    elsif a.lethality < b.lethality
      1
    else
      b.size <=> a.size
    end
  end

  teams
end

set :bind, '0.0.0.0'
set :server, :puma

get '/' do
  haml :index
end

get '/teams' do
  content_type :json
  JSON.pretty_generate(stats)
end
