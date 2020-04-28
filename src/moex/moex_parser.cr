module Moex
  struct Parser
    CONTRACT_URL = "https://www.moex.com/ru/contract.aspx?code="

    def initialize(@timeout = 3000, @filepath = "", @ff_address = "localhost")
    end

    def go(obj : News)
      parse_news obj.url
    end

    def go(obj : Contract)
      parse_contract obj.code
    end

    def parse_news(url : String)
      # рестартим браузер, потому что он постоянно зависает :(
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.restart
      end
      sleep 5.second
      _parse_news(url)
    end

    def parse_contract(code : String)
      actual_code = ""
      # пытаемся узнать какой контракт является актуальным, после рестартим браузер и отправляем парсить по актуальному контракту
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto(CONTRACT_URL + code)
        sleep 5.seconds
        last_action_date_td = b.find_element(:xpath, "/html/body/div[2]/div[3]/div/div/div[1]/div/div/div/div/div[2]/form/div[3]/div[3]/div[3]/div/table/tbody/tr[1]/td[9]")
        unless last_action_date_td.nil?
          last_time = Time.parse(last_action_date_td.text, "%d.%m.%y", Time::Location::UTC)
          # если до даты исполнения последнего контракта меньше или равно три дня
          if (last_time - 3.days) <= Time.utc
            # тогда возвращаем следующий контракт
            next_contract_name = b.find_element(:xpath, "/html/body/div[2]/div[3]/div/div/div[1]/div/div/div/div/div[2]/form/div[3]/div[3]/div[3]/div/table/tbody/tr[2]/td[1]/a")
            actual_code = next_contract_name.text unless next_contract_name.nil?
          else
            current_contract_name = b.find_element(:xpath, "/html/body/div[2]/div[3]/div/div/div[1]/div/div/div/div/div[2]/form/div[3]/div[3]/div[3]/div/table/tbody/tr[1]/td[1]/a")
            actual_code = current_contract_name.text unless current_contract_name.nil?
          end
        end
        b.restart
      end
      sleep 5.second
      _parse_contract(actual_code)
    end

    private def _parse_news(url)
      ret = Hash(Symbol, Array(String) | String).new
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto(url)
        ret[:title] = title[19..]? || ""
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

    private def _parse_contract(code : String)
      url = CONTRACT_URL + code
      ret = Hash(Symbol, Array(String) | String).new
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto(url)
        sleep 5.seconds
        update_time_div = b.find_element(:xpath, "//*[@id='digest_refresh_time']")
        update_time = update_time_div.text unless update_time_div.nil?
        images = [] of String
        b.find_elements(:xpath, "//table[@class='tool_options_table_forts']").each_with_index do |table_element, idx|
          file = @filepath + "table-#{table_element.id}.png"
          table_element.save_screenshot(file, full: false, scroll: false)
          images << file
        end
        ret[:images] = images
        ret[:title] = "Сводка по рынку"
        ret[:text] = "##{code} по состоянию на #{update_time}\n"
        ret[:url] = url
      end

      ret
    end
  end
end
