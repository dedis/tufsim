#!/usr/bin/env ruby
#
#

require 'optparse'
require 'date'

require_relative 'skipblock'
require_relative 'mockup'
require_relative 'processor'

DEFAULT_BASE = 2
DEFAULT_HEIGHT = 2
DEFAULT_OUTPUT = "result.csv"

@options = {:base => DEFAULT_BASE, :height => DEFAULT_HEIGHT, :type => :local,
            :out => DEFAULT_OUTPUT }

OptionParser.new do |opts|
    opts.banner = "Usage tufsim.rb <processor> [options]"
    opts.on("-b","--base BASE",'Base of the skiplist') do |b|
        @options[:base] = b.to_i
    end
    opts.on("-i","--heigh HEIGHT","Maximum height of the skiplist") do |h|
        @options[:height] = h.to_i
    end
    opts.on("-n","--head NUMBER","Takes only the first NUMBER snapshots") do |n|
        @options[:head] = n.to_i
    end
    opts.on("-t","--type TYPE","Between SSH and LOCAL") do |t|
        @options[:type] = t.downcase.to_sym
    end
    opts.on("-o","--out FILE","File to output result") do |o|
        @options[:out] = o
    end
    opts.on('-h', '--help', 'Displays Help') do
        puts opts
        exit
    end
end.parse!

def args
    abort("[-] Not enough arguments") if ARGV.empty?
    @options[:processor]= ARGV.shift
end

def new_mockup
    case @options[:type]
    when :local
        m = Mockup::Local.new
        m.packages_size
        yield m
    when :ssh
        m = Mockup::SSH.new
        m.connect
        m.packages_size
        yield m
        m.close
    else
        abort("[-] Unknown mockup class")
    end
end

def main
    puts "[+] Tufsim.rb (#{@options[:type]}) <#{@options[:processor]}> with base = #{@options[:base]} & height = #{@options[:height]}"
    result = nil
    new_mockup do |mockup|
        ## first get the list of snapshots
        snaps = mockup.snapshots
        ## construct the skiplist out of it
        skiplist = Skipchain::create_skiplist snaps, Skipchain::Config.new(@options[:base],@options[:height],@options[:head])
        ## fetch and map the client updates
        updates = mockup.client_updates skiplist.mapping_client_update()

        ## verification
        #tssSkip = skiplist.timestamps
        #updates.each do |k,v|
        #    puts "WOW" if v.find_all { |ts| !tssSkip.key?(ts)}.size > 0
        #end

        ## run the processor
        processor = nil
        case @options[:processor].downcase
        when "onelevel"
            processor = Processor::OneLevel.new mockup,updates,skiplist
            result = processor.processOneLevel
        end
    end
    puts "[+] Processing terminated"
    ## write to file
    File.open(@options[:out],"w+") do |f|
        f.write("time, cumul_bandwith_#{@options[:processor]}\n")
        result.each do |k,v|
            d = Time.at(k).utc.to_datetime
            f.write("#{d.strftime("%Y-%m-%d %H:%M:%S")}, #{v}\n")
        end
    end
end

args
main
