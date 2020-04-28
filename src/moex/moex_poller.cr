module Moex
  class Poller
    NEWS_URL     = "https://www.moex.com/ru/news/"
    CONTRACT_URL = "https://www.moex.com/ru/contract.aspx?code="
    @prev_url : String = ""
    @contract_codes : Array(String)
    @sent_update : Bool = false

    def initialize(@send_last : Bool, @contract_codes : Array(String))
      @sent_update = !@send_last
    end

    def subscribe
      # если send_last = true, тогда перед циклом не проставляем prev_url последней новостью
      # что заставит рутину ниже отправить в канал последнюю новость
      # должно стоять false, что бы бот при краше не переотправлял новость, которую возможно уже отправил
      @prev_url = get_last_url unless @send_last
      chan = Channel(Contract | News).new
      spawn do
        loop do
          begin
            last_url = get_last_url
            # проверяем есть ли новости и отправляем
            if last_url != @prev_url && !last_url.empty?
              @prev_url = last_url
              chan.send News.new(last_url)
            end
            # и отправляем сводку по контрактам
            get_contracts { |contract| chan.send contract }
          rescue e
            puts "Exception caugh in subscribe spawn loop: #{e.message}"
          end
          sleep 60.second
        end
      end
      chan
    end

    private def get_contracts
      if time_to_send_contracts? && !@sent_update
        @contract_codes.each do |code|
          yield Contract.new(code)
        end
        @sent_update = true
      elsif !time_to_send_contracts?
        @sent_update = false
      end
    end

    private def time_to_send_contracts?
      current_time = Time.local(location: Time::Location.load("Europe/Moscow"))
      # с 10:00 до 19:00 по будням
      (current_time.hour >= 10 && current_time.hour <= 19) && current_time.day_of_week.to_s.in? %w(Monday Tuesday Wednesday Thursday Friday)
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
