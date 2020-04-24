require "http/client"
require "xml"

module Moex
  class Poller
    NEWS_URL = "https://www.moex.com/ru/news/"
    @prev_url : String = ""

    def initialize(@send_last : Bool)
    end

    def subscribe
      # если send_last = true, тогда перед циклом не проставляем prev_url последней новостью
      # что заставит рутину ниже отправить в канал последнюю новость
      # должно стоять false, что бы бот при краше не переотправлял новость, которую возможно уже отправил
      @prev_url = get_last_url unless @send_last
      chan = Channel(String).new
      spawn do
        loop do
          begin
            last_url = get_last_url
            if last_url != @prev_url && !last_url.empty?
              @prev_url = last_url
              chan.send last_url
            end
          rescue e
            puts "Exception caugh in subscribe spawn loop: #{e.message}"
          end
          sleep 120.second
        end
      end
      chan
    end

    private def get_last_url
      resp = HTTP::Client.get(NEWS_URL)
      xml_nodes = XML.parse_html(resp.body)
      link_a_node = xml_nodes.xpath_node("//a[@class='news-list__link']")
      href = link_a_node["href"]? unless link_a_node.nil?
      if href.nil?
        ""
      else
        NEWS_URL[..-10] + href
      end
    end
  end
end
