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
class << self; attr_reader :options; end;

OptionParser.new do |opts|
    opts.banner = "Usage tufsim.rb <processor> [options]"
    opts.on("-b","--base BASE",'Base of the skiplist') do |b|
        @options[:base] = b.to_i
    end
    opts.on("-i","--heigh HEIGHT","Maximum height of the skiplist") do |h|
        @options[:height] = h.to_i
    end
    opts.on("-s","--snapshot-head NUMBER","Takes only the first NUMBER snapshots") do |n|
        @options[:snap_head] = n.to_i
    end
    opts.on("-c","--client-head NUMBER","Takes only the first NUMBER of client updates") do |c|
        @options[:client_head] = c.to_i
    end
    opts.on("-f","--fixed","Fixed size for all skipblocks (not taking into account the height") do |s|
        @options[:fixed] = true
    end
    opts.on("-t","--type TYPE","Between SSH and LOCAL") do |t|
        @options[:type] = t.downcase.to_sym
    end
    opts.on("-o","--out FILE","File to output result") do |o|
        @options[:out] = o
    end
    opts.on("-v","--verbose","verbosity enabled") do |v|
        @options[:v] = true
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
        m = Mockup::Local.new @options
        m.packages_size
        yield m
    when :ssh
        m = Mockup::SSH.new @options
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
        config = Skipchain::Config.new(@options[:base],@options[:height])
        ## first get the list of snapshots
        snaps = mockup.snapshots @options[:snap_head]
        ## construct the skiplist out of it
        skiplist = Skipchain::create_skiplist snaps, config
        ## fetch and map the client updates
        updates = mockup.client_updates skiplist.mapping_client_update(),@options[:client_head]

        ## run the processor
        result  = Processor::process @options[:processor],mockup,updates, skiplist,@options
    end
    puts "[+] Processing terminated"
    ## write to file
    File.open(@options[:out],"w+") do |f|
        columns = (["base","height"] + result.shift).join(", ")  + "\n"
        f.write columns
        result.first.each do |values|
            f.write ([@options[:base],@options[:height]] + values).join(", ") + "\n"
        end
    end
    puts "[+] Results written to #{@options[:out]}"
end

args
main
