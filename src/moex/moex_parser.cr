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

    private def parse_news(url : String)
      ret = Hash(Symbol, Array(String) | String).new

      resp = HTTP::Client.get(url)
      root = XML.parse_html(resp.body)

      title_node = root.xpath_node("//title")
      ret[:title] = (title_node.text[22..] unless title_node.nil?) || ""

      text = ""
      root.xpath_nodes("//div[@class='news_text']/*[not(self::div[@class='row'] or self::table)]").each do |node|
        # для телеги нам надо только текст + <a> ссылки
        text += node.text + "\n\n"
        a = node.xpath_node(".//a[@href]")
        unless a.nil?
          text = text.gsub(a.text, "<a href=\"#{a["href"]}\">#{a.text}</a>")
        end
      end

      if text.empty?
        # попробуем распарсить текст из самого div class='news_text'
        node = root.xpath_node("//div[@class='news_text'][not(self::div[@class='row'] or self::table)]")
        text = node.text unless node.nil?
      end

      ret[:images] = Array(String).new
      # если в документе есть таблички, запускаем браузер и скриншотим их
      unless root.xpath_node("//table[@class='table1']").nil?
        ret[:images] = table_screenshots_for url
      end
      ret[:url] = url
      ret[:text] = text
      ret
    end

    private def table_screenshots_for(url)
      images = Array(String).new
      # ребутаем браузер перед использованием, потому что он может зависнуть :(
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout).restart
      sleep 5.seconds
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto url
        b.find_elements(:xpath, "//table[@class='table1']").each do |table_element|
          file = @filepath + "table-#{table_element.id}.png"
          table_element.save_screenshot(file, full: false, scroll: false)
          images << file
        end
      end
      images
    end

    # парсим браузером вместо XML, потому что контент динамический
    private def parse_contract(code : String)
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

    private def _parse_contract(code : String)
      url = CONTRACT_URL + code
      ret = Hash(Symbol, Array(String) | String).new
      Marionette.launch(address: @ff_address, executable: false, timeout: @timeout) do |b|
        b.goto(url)
        sleep 5.seconds
        update_time_div = b.find_element(:xpath, "//*[@id='digest_refresh_time']")
        update_time = update_time_div.text unless update_time_div.nil?
        images = [] of String
        b.find_elements(:xpath, "//div[@class='left-block']|//div[@class='right-block']").each_with_index do |table_element, idx|
          file = @filepath + "table-#{table_element.id}.png"
          table_element.save_screenshot(file, full: false, scroll: false)
          images << file
        end
        ret[:images] = images.reverse
        ret[:title] = "Сводка по рынку"
        ret[:text] = "##{code} по состоянию на #{update_time}\n"
        ret[:url] = url
      end
      ret
    end
  end
end
