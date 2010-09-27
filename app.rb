#! /usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'yaml'
require 'openid'
require 'openid/store/filesystem'
require 'mongo'

use Rack::Session::Cookie

configure do
  mongo_url = ENV["MONGOHQ_URL"]
  if mongo_url
    uri = URI.parse(mongo_url)
    cn = Mongo::Connection.from_uri(mongo_url)
    DB = cn.db(uri.path.gsub(/^\//,''))
  else
    DB = Mongo::Connection.new.db("rpsgame")
  end
end

before do
  protected! unless request.path_info == '/' || request.path_info[/^\/login/]
end

helpers do
  def openid_consumer
    #@openid_consumer ||= OpenID::Consumer.new(session, OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))  
    @openid_consumer ||= OpenID::Consumer.new(session, nil)
  end

  def root_url
    request.url.match(/(^.*\/{2}[^\/]*)/)[1]
  end

  def current_user
    session["current_user"]
  end

  def logged_in
    !!current_user
  end

  def protected!
    redirect '/' unless logged_in 
  end

  def users
    DB["users"]
  end
end

get '/' do
  haml :index
end

get '/settings' do
  haml :settings
end

post '/settings' do
  current_user["color"] = params[:color]
  users.save(current_user)
  redirect '/'
end

post '/challenge' do
  opponent_id = params[:opponent]
  opponent = users.find_one({:identity => opponent_id})
  return "Who? <a href='/'>Try again</a>" if opponent.nil?
  # start a game
  redirect '/'
end


post '/login/openid' do
  openid = params[:openid_identifier]
  begin
    oidreq = openid_consumer.begin(openid)
  rescue OpenID::DiscoveryFailure => why
    "Sorry, we couldn't find your identifier '#{openid}'"
  else
    # You could request additional information here - see specs:
    # http://openid.net/specs/openid-simple-registration-extension-1_0.html
    # oidreq.add_extension_arg('sreg','required','nickname')
    # oidreq.add_extension_arg('sreg','optional','fullname, email')
    
    # Send request - first parameter: Trusted Site,
    # second parameter: redirect target
    redirect oidreq.redirect_url(root_url, root_url + "/login/openid/complete")
  end
end

get '/login/openid/complete' do
  oidresp = openid_consumer.complete(params, request.url)

  case oidresp.status
    when OpenID::Consumer::FAILURE
      "Sorry, we could not authenticate you with the identifier '{openid}'."

    when OpenID::Consumer::SETUP_NEEDED
      "Immediate request failed - Setup Needed"

    when OpenID::Consumer::CANCEL
      "Login cancelled."

    when OpenID::Consumer::SUCCESS
      user = users.find_one({:identity => oidresp.identity_url}) 
      if user.nil?
        user = {:identity => oidresp.identity_url}
        users.insert(user)
      end
      session["current_user"] = user 
      redirect "/"
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

__END__

@@ index
= haml :login_status, :layout => false

- if !logged_in
  %form{ :action => "/login/openid", :method => "post" }
    %label
      OpenID URL:
      %input{ :type => 'text', :name => 'openid_identifier' }
    %input{ :type => 'submit', :value => 'Login' }
- else
  %a{ :href => '/settings' } Settings 
  %form{ :action => "/challenge", :method => "post" }
    %label
      Opponent ID:
      %input{ :type => "text", :name => "opponent" }
    %input{ :type => "submit", :value => "Challenge" }

@@ settings
= haml :login_status, :layout => false
%form{ :action => "/settings", :method => "post" }
  %label
    Favorite color:
    %input{ :type => "text", :name => "color" }
  %input{ :type => "submit", "value" => "Configure" }

@@ login_status
.status
  - if logged_in
    :css
      body {
        background-color: #{ current_user["color"] || "#fff" };
      }
    %p
      == Logged in as #{ current_user["identity"] }
      %a{ :href => '/logout' } Logout
  - else
    %p Not logged in

