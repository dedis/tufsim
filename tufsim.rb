#!/usr/bin/env ruby
#
#

require 'optparse'

require_relative 'skipblock'
require_relative 'mockup'

DEFAULT_BASE = 2
DEFAULT_HEIGHT = 2
@options = {:base => DEFAULT_BASE, :height => DEFAULT_HEIGHT}

OptionParser.new do |opts|
    opts.banner = "Usage tufsim.rb [options]"
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

def main 
    puts "[+] tufsim.rb with base = #{@options[:base]} & height = #{@options[:height]}"
    # instantiate mockup class
    mockup = Mockup.new
    mockup.connect
    ## first get the list of snapshots
    snaps = mockup.snapshots 
    ## construct the skiplist out of it
    skiplist = Skipchain::create_skiplist snaps, Skipchain::Config.new(@options[:base],@options[:height],@options[:head])

    updates = mockup.client_updates skiplist.mapping_client_update()

    mockup.close
end

main
