#!/usr/bin/env ruby
#
#

require 'optparse'

require_relative 'skipblock'
require_relative 'mockup'
require_relative 'processor'

DEFAULT_BASE = 2
DEFAULT_HEIGHT = 2

@options = {:base => DEFAULT_BASE, :height => DEFAULT_HEIGHT}

OptionParser.new do |opts|
    opts.banner = "Usage tufsim.rb <processor> [options]"
    opts.on("-b","--base BASE",'Base of the skiplist') do |b|
        @options[:base] = b.to_i
    end
    opts.on("-l","--heigh HEIGHT","Maximum height of the skiplist") do |h|
        @options[:height] = h.to_i
    end
    opts.on("-n","--head NUMBER","Takes only the first NUMBER snapshots") do |n|
        @options[:head] = n.to_i
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

def main 
    puts "[+] Tufsim.rb <#{@options[:processor]}> with base = #{@options[:base]} & height = #{@options[:height]}"
    # instantiate mockup class
    mockup = Mockup::SSH.new
    mockup.connect
    ## first get the list of snapshots
    snaps = mockup.snapshots 
    ## then the packages
    mockup.packages_size
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
    end
    result = processor.process
    mockup.close
end

args
main
