require "tourmaline"

module Telegram
  class PublisherBot < Tourmaline::Client
    @chat_id : Int64

    def initialize(@chat_id, *args)
      super *args
    end

    def send_moex_update(obj)
      images = obj[:images].as(Array(String))
      if images.empty?
        msg = "<b>#{obj[:title][19..]?}</b>\n\n#{obj[:text]}\n#{obj[:url]}"
        send_message(@chat_id, msg, parse_mode = :html)
      elsif obj[:images].size == 1
        msg = "<b>#{obj[:title][19..]?}</b>\n\n#{obj[:text][..900]}\n#{obj[:url]}"
        image = obj[:images][0].as(String)
        send_media_group(@chat_id, [InputMediaPhoto.new(media: image, caption: msg, parse_mode: "html")])
        # fails with "unknown parse_mode" bullshit...
        # send_photo(@chat_id, photo: image, caption: msg, parse_mode: :markdown)
      else
        msg = "<b>#{obj[:title][19..]?}</b>\n\n#{obj[:text]}\n#{obj[:url]}"
        send_message(@chat_id, msg, parse_mode = :html)
        input_medias = images.each_with_object([] of InputMediaPhoto) do |img, memo|
          memo << InputMediaPhoto.new(media: img)
        end
        send_media_group(@chat_id, input_medias)
      end
    end
  end
end
