require "marionette"

module Moex
  struct Parser
    def initialize(@timeout = 3000, @filepath = "", @ff_address = "localhost")
    end

    def go(url)
      ret = Hash(Symbol, Array(String) | String).new
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto(url)
        ret[:title] = title
        text = ""
        # основной контент новости тут, нам надо все, кроме таблиц и футера с копирайтом
        b.find_elements(:xpath, "//div[@class='news_text']/*[not(self::div[@class='row'] or self::div[@class='table-scroller'])]").each do |elem|
          text += elem.text + "\n\n"
        end

        if text.empty?
          # попробуем распарсить текст из самого div class='news_text'
          div = b.find_element(:xpath, "//div[@class='news_text'][not(self::div[@class='row'] or self::div[@class='table-scroller'])]")
          text = div.text + "\n" unless div.nil?
        end

        ret[:text] = text
        images = [] of String
        # находим и скриншотим все таблички
        b.find_elements(:xpath, "//table[@class='table1']").each_with_index do |table_element, idx|
          file = @filepath + "table-#{table_element.id}.png"
          table_element.save_screenshot(file, full: false, scroll: false)
          images << file
        end
        ret[:images] = images
      end
      ret[:url] = url
      ret
    end
  end
end
