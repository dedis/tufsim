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
    opts.on("-b","--heigh HEIGHT","Maximum height of the skiplist") do |h|
        @options[:height] = h.to_i
    end
    opts.on('-h', '--help', 'Displays Help') do
        puts opts
        exit
    end
end.parse!

def main 
    puts "[+] tufsim.rb with base = #{@options[:base]} & height =#{@options[:height]}"
    ## first get the list of snapshots
    snaps = Mockup.snapshots 

    ## construct the skiplist out of it

end

main
