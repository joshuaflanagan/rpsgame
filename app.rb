#! /usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'rack/openid'
require 'yaml'

use Rack::Session::Cookie
use Rack::OpenID

before do
  protected! unless request.path_info == '/' || request.path_info[/^\/login/]
end

helpers do
  def current_user
    session["current_user"]
  end

  def logged_in
    !!current_user
  end

  def protected!
    redirect '/' unless logged_in 
  end
end

get '/' do
  haml :index
end

get '/another' do
  haml :another
end

post '/login' do
  openid_response = env["rack.openid.response"]
  if openid_response
    if openid_response.status == :success
      session["current_user"] = openid_response.identity_url
      redirect '/'
    else
      session.clear
      "<pre>#{ openid_response.to_yaml }</pre> <a href='/'>Try again</a>"
    end
  else
    headers 'WWW-Authenticate' => Rack::OpenID.build_header(
      :identifier => params["openid_identifier"]
    )
    throw :halt, [401, 'got openid?']
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
  %form{ :action => "/login", :method => "post" }
    %label
      OpenID URL:
      %input{ :type => 'text', :name => 'openid_identifier' }
    %input{ :type => 'submit', :value => 'Login' }
- else
  %a{ :href => '/another' } Go to another page

@@ another
= haml :login_status, :layout => false
%p This is another page


@@ login_status
.status
  - if logged_in
    %p
      == Logged in as #{ current_user }
      %a{ :href => '/logout' } Logout
  - else
    %p Not logged in

