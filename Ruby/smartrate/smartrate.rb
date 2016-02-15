#!/usr/bin/env ruby

require 'open-uri'

require 'rubygems'
require 'nokogiri'
require 'holidays'
require 'holidays/us'

smartrate = "http://www.pge.com/en/myhome/saveenergymoney/plans/smartrate/history/index.page"
page = Nokogiri::HTML(open(smartrate))
Smartdays = page.css("div[class='an_c5-content-block']").css("li").select { |item| item.text[/20\d\d$/] }.map { |day| Date.parse(day.text) }.sort
#Smartdays.each { |day| puts day }

def smartday? date
  return Smartdays.include? Date.parse(date.strftime('%Y-%m-%d'))
end


def demand date
  # see http://www.pge.com/en/myhome/saveenergymoney/plans/tou/index.page
  # May-October
  #   Weekdays
  #     0000-1000 low
  #     1000-1300 medium
  #     1300-1900 high
  #     1900-2100 medium
  #     2100-2400 low
  #   Weekends
  #     0000-1700 low
  #     1700-2000 medium
  #     2000-2400 low
  #   Holidays
  #     0000-2400 low
  # November-April
  #   Weekdays
  #     0000-1700 low
  #     1700-2000 medium
  #     2000-2400 low
  #   Weekends
  #     0000-2400 low
  #   Holidays
  #     0000-2400 low
  #
  hour = date.hour * 100
  season = date.month >= 5 && date.month <= 10 ? :summer : :winter
  if (smartday? date) && hour >= 1400 && hour < 1900
    # Shift or reduce your energy usage 2-7 p.m. during smartday
    day = :smartday
  else
    day = (date.holiday? :us) ? :holiday : (date.wday > 0 && date.wday < 6) ? :weekday : :weekend
  end

  case day
  when :smartday
    rate = :max
  when :holiday
    rate = :low
  when :weekend
    case season
    when :summer
      if hour < 1700
        rate = :low
      elsif hour < 2000
        rate = :medium
      else
        rate = :low
      end
    when :winter
      rate = :low
    end
  when :weekday
    case season
    when :summer
      if hour < 1000
        rate = :low
      elsif hour < 1300
        rate = :medium
      elsif hour < 1900
        rate = :high
      elsif hour < 2100
        rate = :medium
      else
        rate = :low
      end
    when :winter
      if hour < 1700
        rate = :low
      elsif hour < 2000
        rate = :medium
      else
        rate = :low
      end
    end
  end
  puts "#{date.strftime('%a %b %-d, %Y %I:%M %p')} => #{season} #{day} #{rate}"
end


def demand_range date
  meridian = DateTime.parse(date.strftime("%d/%m/%Y #{date.hour / 12 * 12}:00"))
  (0..23).each { |hour|
    demand meridian + (hour / 24.0)
  }
end



demand_range DateTime.now



def test_demand
  demand DateTime.parse("28/08/2015 14:00")
  demand DateTime.parse("04/07/2015 13:00")
  demand DateTime.parse("01/05/2015 01:00")
  demand DateTime.parse("01/05/2015 10:00")
  demand DateTime.parse("01/05/2015 13:00")
  demand DateTime.parse("01/05/2015 19:00")
  demand DateTime.parse("01/05/2015 21:00")
  demand DateTime.parse("02/05/2015 01:00")
  demand DateTime.parse("02/05/2015 17:00")
  demand DateTime.parse("02/05/2015 20:00")
  demand DateTime.parse("02/11/2015 01:00")
  demand DateTime.parse("02/11/2015 17:00")
  demand DateTime.parse("02/11/2015 20:00")
  demand DateTime.parse("01/11/2015 01:00")
  demand DateTime.parse("25/12/2015 01:00")
end
#test_demand


# ------------------------------------------------------------------------------- [Webserver]
# -------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------

require 'webrick'

class Webserver
  def initialize options
    @webserver = WEBrick::HTTPServer.new :Port => 8888
    @webserver.mount("/CoolClock/", Resource, './CoolClock')
    @webserver.mount '/', Simple
    trap 'INT' do @webserver.shutdown end
  end

  def self.run! options
    Webserver.new(options).run!
  end

  def run!
    @webserver.start
  end
end

class Resource < WEBrick::HTTPServlet::FileHandler
  def do_POST request, response
    response.status = 200
  end
end

class Simple < WEBrick::HTTPServlet::AbstractServlet
  def encode_entities str
    str
  end

  def do_GET request, response
    case request.path
    when '/'
    end
    response.status = 200
  end
end

Webserver.run! nil
