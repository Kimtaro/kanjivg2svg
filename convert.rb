# Encoding: UTF-8

require 'rubygems'
require 'nokogiri'
require 'pp'

class Importer
  class KanjiVG
    
    SVG_HEAD = '<svg width="120" height="120" viewBox="-5 -5 120 120" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" version="1.1"  baseProfile="full">'
    SVG_FOOT = '</svg>'
    TEXT_STYLE = 'fill:#FF2A00;font-family:Helvetica;font-weight:bold;font-size:15;stroke-width:0'
    PATH_STYLE = 'fill:none;stroke:black;stroke-width:3'
    PATH_START_RE = %r{^M (\d+ (?:\.\d+)?) , (\d+ (?:\.\d+)?)}ix
    
    def initialize(doc, output_dir, animate = false, verbose = false)
      @verbose = verbose
      @entry_name = 'kanji'
      @output_dir = output_dir
      @animate = animate
      processed = 0

      puts "Starting the conversion @ #{Time.now} ..." if @verbose
      
      # Don't want Nokogiri to read in the entire document at once
      # So doing it entry by entry
      tmp = ""
      begin
        while (line = doc.readline)
          if line =~ %r{<#{@entry_name}}
            tmp = line
          elsif line =~ %r{</#{@entry_name}>}
            tmp << line
            noko = Nokogiri::XML(tmp)
            parse(noko)
            
            processed += 1
            if processed % 1000 == 0
              puts "Processed #{processed} @ #{Time.now}" if @verbose
            end
          else
            tmp << line
          end
        end
      rescue EOFError
        doc.close
      end
    end
    
    def parse(doc)
      doc.css(@entry_name).each do |entry|
        codepoint = entry['id']
        svg = File.open("#{@output_dir}/U+#{codepoint}#{@animate ? '_animated' : ''}.svg", File::RDWR|File::TRUNC|File::CREAT)
        svg << "#{SVG_HEAD}\n"
        stroke_count = 0

        entry.css('stroke').each do |stroke|
          md = PATH_START_RE.match(stroke['path'])
          x = md[1].to_f
          y = md[2].to_f
          
          x -= 5
          y -= 2
          
          stroke_count += 1
          
          base_path = "<path d=\"#{stroke['path']}\""
          if @animate
            svg << "#{base_path} style=\"#{PATH_STYLE};opacity:0\">\n"
            svg << "  <animate attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" begin=\"#{stroke_count-1}s\" dur=\"1s\" repeatCount=\"0\" fill=\"freeze\" />\n"
            svg << "</path>\n"
          else
            svg << "<text x=\"#{x}\" y=\"#{y}\" style=\"#{TEXT_STYLE}\">#{stroke_count}</text>\n"
            svg << "#{base_path} style=\"#{PATH_STYLE}\" />\n"
          end
        end

        svg << SVG_FOOT
        svg.close
      end
    end
    
  end
end

file = ARGV[0]
Importer::KanjiVG.new(File.open(file), File.expand_path('../svgs',  __FILE__), true, true)
