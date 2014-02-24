# THINGS TO CONFIGURE

ACCESS_TOKEN = 'INSERT YOUR ACCESS TOKEN HERE'
# get your access token at this URL:
# https://stackexchange.com/oauth/dialog?client_id=2666&redirect_uri=http://keyboardfire.com/chatdump.html&scope=no_expiry
$root = 'http://stackexchange.com'
$chatroot = 'http://chat.stackexchange.com'
$room_number = 13215
site = 'codegolf'
# the default is configured for http://chat.stackexchange.com/rooms/13215/chatbot-room
email = 'INSERT YOUR EMAIL HERE'
password = 'INSERT YOUR PASSWORD HERE'

require 'rubygems'
require 'mechanize'
require 'logger'
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'cgi'
require 'net/http'
puts 'requires finished'

loop{begin

$agent = Mechanize.new
$agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
#$agent.log = Logger.new STDOUT

login_form = $agent.get('https://openid.stackexchange.com/account/login').forms.first
login_form.email = email
login_form.password = password
$agent.submit login_form, login_form.buttons.first
puts 'logged in with SE openid'

meta_login_form = $agent.get($root + '/users/login').forms.last
meta_login_form.openid_identifier = 'https://openid.stackexchange.com/'
$agent.submit meta_login_form, meta_login_form.buttons.last
puts 'logged in to root'

chat_login_form = $agent.get('http://stackexchange.com/users/chat-login').forms.last
$agent.submit chat_login_form, chat_login_form.buttons.last
puts 'logged in to chat'

$fkey = $agent.get($chatroot + '/chats/join/favorite').forms.last.fkey
puts 'found fkey'

def send_message text
  loop {
    begin
      resp = $agent.post("#{$chatroot}/chats/#{$room_number}/messages/new", [['text', text], ['fkey', $fkey]]).body
      success = JSON.parse(resp)['id'] != nil
      return if success
    rescue Mechanize::ResponseCodeError => e
      puts "Error: #{e.inspect}"
    end
    puts 'sleeping'
    sleep 3
  }
end

send_message $ERR ? "An unknown error occurred. Bot restarted." : "Bot initialized."
puts 'bot initialized'

last_date = 0
loop {
  uri = URI.parse "https://api.stackexchange.com/2.2/events?pagesize=100&since=#{last_date}&site=#{site}&filter=!9WgJfejF6&key=thqRkHjZhayoReI9ARAODA((&access_token=#{ACCESS_TOKEN}"
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  data = JSON.parse http.get(uri.request_uri).body
  events = data['items']

  data['items'].each do |event|
    last_date = [last_date, event['creation_date'].to_i + 1].max
    #send_message "#{event['event_type'].sub('_', " #{event['event_id']} ").capitalize}: [`#{event['excerpt'].gsub(/\s/, ' ')}`](#{event['link']})"
    unless ['post_edited'].include? event['event_type']
      send_message event['link']
    end
  end

  puts "#{data['quota_remaining']}/#{data['quota_max']} quota remaining"
  sleep(40 + (data['backoff'] || 0).to_i) # add backoff time if any, just in case
}

=begin
Old thing that dumps *all* activity
EM.run {
  ws = Faye::WebSocket::Client.new('ws://sockets.ny.stackexchange.com')

  ws.on :open do |event|
    ws.send('155-questions-active')
  end

  ws.on :message do |event|
    data = JSON.parse JSON.parse(event.data)['data']
    p data
    send_message "Question on #{data['apiSiteParameter']}: [#{data['titleEncodedFancy']}](#{data['url']}) (#{data['tags'] * ','})"
  end
}
=end

rescue => e
  $ERR = e
  p e
end}
