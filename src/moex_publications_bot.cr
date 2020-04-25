require "log"
require "./moex/*"
require "./telegram"

class Main
  @@chat_id : Int64 = (ENV.has_key?("CHAT_ID") ? ENV["CHAT_ID"].to_i64 : 0.to_i64)
  @@api_key : String = ENV["API_KEY"]? || ""
  @@ff_address : String = ENV["FIREFOX_ADDRESS"]? || "localhost"
  @@file_path : String = ENV["IMAGE_TMP_PATH"]? || "/tmp/"
  @@browser_timeout : (Int32 | String) = ENV["BROWSER_TIMEOUT"]? || 30000
  @@send_last : Bool = (ENV["SEND_LAST"]? == "true") || false
  Log.builder.bind "*", :info, Log::IOBackend.new

  def self.configure
    raise "ENV \"CHAT_ID\" is required" if @@chat_id == 0
    raise "ENV \"API_KEY\" is required" if @@api_key.empty?

    puts <<-CONF
    Configured as:
    CHAT_ID: #{@@chat_id}
    API_KEY (shadowed): #{@@api_key[..10]}XXXX....
    IMAGE_TMP_PATH: #{@@file_path}
    BROWSER_TIMEOUT: #{@@browser_timeout}
    SEND_LAST: #{@@send_last}
    FIREFOX_ADDRESS: #{@@ff_address}
    CONF
  end

  def self.run
    parser = Moex::Parser.new(timeout: @@browser_timeout.to_i, filepath: @@file_path, ff_address: @@ff_address)
    poller = Moex::Poller.new(send_last: @@send_last)
    bot = Telegram::PublisherBot.new(@@chat_id, @@api_key)

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
  end
end

begin
  Main.configure
  Main.run
rescue e
  puts "Runtime failed: #{e.message}"
end
