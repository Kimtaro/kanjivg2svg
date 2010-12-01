# Encoding: UTF-8
# By: Kim Ahlström <kim.ahlstrom@gmail.com>
# License: Creative Commons Attribution-Share Alike 3.0 - http://creativecommons.org/licenses/by-sa/3.0/
# KanjiVG is copyright (c) 2009/2010 Ulrich Apel and released under the Creative Commons Attribution-Share Alike 3.0

require 'rubygems'
require 'nokogiri'
require 'pp'

class Importer
  class KanjiVG
    
    WIDTH = 109 # 109 per character
    HEIGHT = 109 # 109 per character
    SVG_HEAD = "<svg width=\"__WIDTH__px\" height=\"#{HEIGHT}px\" viewBox=\"0 0 __VIEW_WIDTH__px #{HEIGHT}px\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xml:space=\"preserve\" version=\"1.1\"  baseProfile=\"full\">"
    SVG_FOOT = '</svg>'
    TEXT_STYLE = 'fill:#FF2A00;font-family:Helvetica;font-weight:normal;font-size:14;stroke-width:0'
    PATH_STYLE = 'fill:none;stroke:black;stroke-width:3'
    INACTIVE_PATH_STYLE = 'fill:none;stroke:#999;stroke-width:3'
    LINE_STYLE = 'stroke:#ddd;stroke-width:2'
    DASHED_LINE_STYLE = 'stroke:#ddd;stroke-width:2;stroke-dasharray:3 3'
    ENTRY_NAME = 'kanji'
    COORD_RE = %r{(?ix:\d+ (?:\.\d+)?)}
    
    def initialize(doc, output_dir, type = :numbers, verbose = false)
      @output_dir = output_dir
      @type = type
      @verbose = verbose
      processed = 0

      puts "Starting the conversion @ #{Time.now} ..." if @verbose
      
      # Don't want Nokogiri to read in the entire document at once
      # So doing it entry by entry
      tmp = ""
      begin
        while (line = doc.readline)
          if line =~ %r{<#{ENTRY_NAME}}
            tmp = line
          elsif line =~ %r{</#{ENTRY_NAME}>}
            tmp << line
            noko = Nokogiri::XML(tmp)
            parse(noko)
            
            processed += 1
            if processed % 200 == 0
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
    
    private
    
    def parse(doc)
      doc.css(ENTRY_NAME).each do |entry|
        codepoint = entry['midashi'].codepoints.first
        svg = File.open("#{@output_dir}/#{codepoint}_#{@type}.svg", File::RDWR|File::TRUNC|File::CREAT)
        stroke_count = 0
        stroke_total = entry.css('stroke[path]').length
        paths = []
        
        # Generate the header
        if @type == :frames
          width = (WIDTH * stroke_total)# + (2 * (stroke_total - 1))
          view_width = width
        else
          width = WIDTH * 1
        end
        header = SVG_HEAD.gsub('__WIDTH__', width.to_s)
        header = header.gsub('__VIEW_WIDTH__', view_width.to_s)
        svg << "#{header}\n"
        
        # Guide lines
        if @type == :frames
          # Outer box
          top = 1; left = 1; bottom = HEIGHT - 1; right = width - 1
          svg << line(left, top, right, top, LINE_STYLE) # top
          svg << line(left, top, left, bottom, LINE_STYLE) # left
          svg << line(left, bottom, right, bottom, LINE_STYLE) # bottom
          svg << line(right, top, right, bottom, LINE_STYLE) # right
          
          (1 .. stroke_total - 1).each do |i|
            svg << line(WIDTH * i, top, WIDTH * i, bottom, LINE_STYLE)
          end
          
          # Inner guides
          svg << line(left, (HEIGHT/2), right, (HEIGHT/2), DASHED_LINE_STYLE)
          
          (1 .. stroke_total).each do |i|
            svg << line((WIDTH/2)+(WIDTH*(i-1)+1), top, (WIDTH/2)+(WIDTH*(i-1)+1), bottom, DASHED_LINE_STYLE)
          end
        end
        
        # Draw the strokes
        entry.css('stroke[path]').each do |stroke|
          paths << stroke['path']
          stroke_count += 1
          
          case @type
          when :animated
            svg << "<path d=\"#{stroke['path']}\" style=\"#{PATH_STYLE};opacity:0\">\n"
            svg << "  <animate attributeType=\"CSS\" attributeName=\"opacity\" from=\"0\" to=\"1\" begin=\"#{stroke_count-1}s\" dur=\"1s\" repeatCount=\"0\" fill=\"freeze\" />\n"
            svg << "</path>\n"
          when :numbers
            x, y = move_text_relative_to_path(stroke['path'])
            svg << "<text x=\"#{x}\" y=\"#{y}\" style=\"#{TEXT_STYLE}\">#{stroke_count}</text>\n"
            svg << "<path d=\"#{stroke['path']}\" style=\"#{PATH_STYLE}\" />\n"
          when :frames
            md = %r{^[LMT] (#{COORD_RE}) , (#{COORD_RE})}ix.match(paths.last)
            path_start_x = md[1].to_f
            path_start_y = md[2].to_f
            path_start_x += WIDTH * (stroke_count - 1)
            
            paths.each_with_index do |path, i|
              last = ((stroke_count - 1) == i)
              delta = last ? WIDTH * (stroke_count - 1) : WIDTH
              
              # Move strokes relative to the frame
              path.gsub!(%r{([LMT]) (#{COORD_RE})}x) do |m|
                letter = $1
                x  = $2.to_f
                x += delta
                "#{letter}#{x}"
              end
              path.gsub!(%r{(S) (#{COORD_RE}) , (#{COORD_RE}) , (#{COORD_RE})}x) do |m|
                letter = $1
                x1  = $2.to_f
                x1 += delta
                x2  = $4.to_f
                x2 += delta
                "#{letter},#{x1},#{$3},#{x2}"
              end
              path.gsub!(%r{(C) (#{COORD_RE}) , (#{COORD_RE}) , (#{COORD_RE}) , (#{COORD_RE}) , (#{COORD_RE})}x) do |m|
                letter  = $1
                x1  = $2.to_f
                x1 += delta
                x2  = $4.to_f
                x2 += delta
                x3  = $6.to_f
                x3 += delta
                "#{letter}#{x1},#{$3},#{x2},#{$5},#{x3}"
              end
              
              svg << "<path d=\"#{path}\" style=\"#{last ? PATH_STYLE : INACTIVE_PATH_STYLE}\" />\n"
            end
            
            # Put a circle at the stroke start
            svg << "<circle cx=\"#{path_start_x}\" cy=\"#{path_start_y}\" r=\"5\" stroke-width=\"0\" fill=\"#FF2A00\" opacity=\"0.7\" />"
            svg << "\n"
          end
        end

        svg << SVG_FOOT
        svg.close
      end
    end
    
    # TODO: make this shit really smart
    def move_text_relative_to_path(path)
      md = %r{^M (#{COORD_RE}) , (#{COORD_RE})}ix.match(path)
      path_start_x = md[1].to_f
      path_start_y = md[2].to_f
      
      text_x = path_start_x
      text_y = path_start_y
      
      [text_x, text_y]
    end
    
    def line(x1, y1, x2, y2, style)
      "<line x1=\"#{x1}\" y1=\"#{y1}\" x2=\"#{x2}\" y2=\"#{y2}\" style=\"#{style}\" />\n"
    end
    
  end
end

file = ARGV[0]
Importer::KanjiVG.new(File.open(file), File.expand_path('../svgs',  __FILE__), :frames, true)
