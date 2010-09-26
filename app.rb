#! /usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'yaml'
require 'openid'
require 'openid/store/filesystem'

use Rack::Session::Cookie

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
end

get '/' do
  haml :index
end

get '/another' do
  haml :another
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
      # Access additional informations:
       puts params['openid.sreg.nickname']
       puts params['openid.sreg.fullname']   
      
      # Startup something
      session["current_user"] = oidresp.identity_url
      redirect "/"
      "Login successfull. <pre>#{ oidresp.to_yaml }</pre>"  
      # Maybe something like
      # session[:user] = User.find_by_openid(oidresp.display_identifier)
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

