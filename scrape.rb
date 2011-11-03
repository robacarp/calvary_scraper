require 'mechanize'
require 'ruby-debug'

class CalvaryScraper

  def scrape
    setup
    series_pages
    messages
    message_detail
    puts @archive.series
  end

  def setup
    @agent = Mechanize.new
    @agent.user_agent_alias = "Windows IE 7"
    @archive = Archive.new
    @base_href = 'http://www.calvarybible.com/downloads/archive/'
  end

  def series_pages
    webpage = @agent.get @base_href + 'index.html'
    year_pages = webpage.links.select{|l| l.to_s.strip.length == 0 }
    year_pages.reject!{|l| l.href.include?('..') || l.href.include?('itunes')}
    year_pages.map{|l| l.href}
    year_pages = webpage.parser.xpath("//div[@id='content']/div/a").map{|e| e.attributes['href'].value}
    year_pages.each do |url|
      webpage = @agent.get @base_href + url
      paths =  webpage.parser.xpath("//div[@id='content']/*/a").map {|e|  e.attributes['href'].value}

      series = paths.select {|p| p.index('index').nil? }       #kill the index.htmtl links
                    .map {|p| @base_href + url[0..4] + p}      #assemble the full urls
                    .flatten                                   #
                    .map {|p| s = Series.new; s.path = p; s}   #make it into a series

      @archive.series.unshift( series )
      @archive.series.flatten!
    end
  end

  # find out how many messages there are in each sermon, allocate the objects,
  #     store the series page parser for use...everywhere...
  def messages
    @archive.series.each do |series|
      series.webpage = @agent.get series.path
      series.title = series.webpage.parser.xpath("//div[@id='series']/h2").children.text

      dates = series.webpage.parser.xpath("//div[@id='series_date']/ul/li")
      dates = dates.map {|d| d.children.text }

      sermon = nil
      dates.each do |date|
        next if date == 'Date'
        # create a new sermon if we're at a new date.  this is an awkward webpage.
        if date != ''
          sermon = series.a_sermon
          sermon.date = date
        end
        sermon.a_message
      end
    end
  end

  #pull out all the real data for the messages...title, speaker, campus, video, audio, notes
  def message_detail
    @archive.series.each do |series|
      titles = series.webpage.parser.xpath("//div[@id='series_title']/ul/li")
               .map {|e| e.children.text }

      speakers = series.webpage.parser.xpath("//div[@id='series_speaker']/ul/li")
                 .map {|e| e.children.text}

      campuses = series.webpage.parser.xpath("//div[@id='series_campus']/ul/li")
                 .map {|e| e.children.text}

      videos = series.webpage.parser.xpath("//div[@id='series_video']/ul/li")
                 .map do |e|
                   link = nil
                   e.children.each do |c|
                     if c.name == 'a'
                       link = c
                       break
                     end
                   end

                   if !link.nil?
                     link.attributes['href'].value.strip
                   else
                     link
                   end
                 end

      audios = series.webpage.parser.xpath("//div[@id='series_audio']/ul/li")
                 .map do |e|
                   link = nil
                   e.children.each do |c|
                     if c.name == 'a'
                       link = c
                       break
                     end
                   end

                   if !link.nil?
                     link.attributes['href'].value.strip
                   else
                     link
                   end
                 end

      notes = series.webpage.parser.xpath("//div[@id='series_notes']/ul/li")
                 .map do |e|
                   link = nil
                   e.children.each do |c|
                     if c.name == 'a'
                       link = c
                       break
                     end
                   end

                   if !link.nil?
                     link.attributes['href'].value.strip
                   else
                     link
                   end
                 end

      #array indexen
      t = s = c = v = a = n = 1;
      lt = ls = lc = 1;

      series.sermons.each do |sermon|
        sermon.messages.each do |message|
          lt = t if titles[t]   != ''
          ls = s if speakers[s] != ''
          lc = c if campuses[c] != ''

          message.title = titles[lt]
          message.speaker = speakers[ls]
          message.video = videos[v]
          message.audio = audios[a]
          message.notes = notes[n]
          message.campus = campuses[c]

          t += 1; s += 1; c += 1; v += 1; a += 1; n+=1;
        end
      end

    end
  end

end

class Archive
  attr_accessor :series
  def initialize
    @series = []
  end
end

class Series
  attr_accessor :sermons, :path, :webpage, :title
  def initialize
    @sermons = []
  end

  def a_sermon
    @sermons << Sermon.new
    @sermons.last
  end

  def to_s
    "title:#{title}\npath: #{path}\n#{sermons.map {|e| e.to_s }.join}\n=======SERIES=============="
  end
end

class Sermon
  attr_accessor :date, :messages

  def parse_date
    return true if @date.kind_of? Date
    bits = @date.split '-'
    return false if !(bits[2] == 11 || bits[2] == 12)
    @date = Time.parse "20#{bits[2]}-#{bits[0]}-#{bits[1]}"
  end

  def initialize
    @messages = []
  end

  def a_message
    @messages << Message.new
    @messages.last
  end

  def to_s
    "#{date}\n#{messages.map{|m| m.to_s}.join} \n---\n"
  end
end

class Message
  attr_accessor :speaker, :audio, :video, :notes, :campus, :title
  def to_s
    "\t\"#{title}\" delivered by #{speaker} at #{campus}:\n\t\tVideo:#{video}\n\t\tAudio:#{audio}\n\t\tnotes:#{notes}\n"
  end
end

f = CalvaryScraper.new
f.scrape
