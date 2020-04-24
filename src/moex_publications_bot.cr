require "log"
require "./moex/*"
require "./telegram"

chat_id = ENV["CHAT_ID"].to_i64
api_key = ENV["API_KEY"]
ff_address = ENV["FIREFOX_ADDRESS"]
file_path = ENV["IMAGE_TMP_PATH"]? || "/tmp/"
browser_timeout = ENV["BROWSER_TIMEOUT"]? || 30000
send_last = (ENV["SEND_LAST"]? == "true") || false

puts "Configured as:\nCHAT_ID: #{chat_id}\nAPI_KEY (shadowed): #{api_key[..10]}XXXX....\nIMAGE_TMP_PATH: #{file_path}\nBROWSER_TIMEOUT: #{browser_timeout}\nSEND_LAST: #{send_last}\nFIREFOX_ADDRESS: #{ff_address}"

parser = Moex::Parser.new(timeout: browser_timeout.to_i, filepath: file_path, ff_address: ff_address)
poller = Moex::Poller.new(send_last: send_last)
bot = Telegram::PublisherBot.new(chat_id, api_key)

backend = Log::IOBackend.new
Log.builder.bind "*", :info, backend

subscribe = poller.subscribe
loop do
  Log.info { "Start polling moex..." }
  obj = parser.go(subscribe.receive)
  begin
    bot.send_moex_update obj
    Log.info { "Sent message => #{obj}" }
  rescue e
    Log.info { "Can't send: #{e.message}" }
  end

  images = obj[:images].as(Array(String))
  unless images.empty?
    Log.info { "Deleting stale screenshots #{images.join(", ")}" }
    images.each { |image| File.delete image }
  end
end
