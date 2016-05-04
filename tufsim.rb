#!/usr/bin/env ruby
#
#

require 'optparse'
require 'date'

require_relative 'skipblock'
require_relative 'mockup'
require_relative 'processor'

DEFAULT_BASE = [2]
DEFAULT_HEIGHT = [2]
DEFAULT_OUTPUT = "result.csv"
DEFAULT_GRAPH = :cumulative

@options = {:base => DEFAULT_BASE, :height => DEFAULT_HEIGHT, :type => :local,
            :out => DEFAULT_OUTPUT, :graph => DEFAULT_GRAPH}
class << self; attr_reader :options; end;

OptionParser.new do |opts|
    opts.banner = "Usage tufsim.rb <processor> [options]"
    opts.on("-b","--base b1,b2,b3",Array,'Bases of the skiplist') do |b|
        @options[:base] = b.map(&:to_i)
    end
    opts.on("-i","--heigh h1,h2,h3",Array, "Maximum height of the skiplist") do |h|
        @options[:height] = h.map(&:to_i)
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
    opts.on("-g","--graph TYPE","TYPE is *cumulative* or *scatter*.Default is *cumulative*") do |g|
        @options[:graph] = g.downcase.to_sym
        ## check if it's correct
        abort("[-] Unknown type of graph #{g}") unless [:cumulative,:scatter].include? @options[:graph]
    end
    opts.on("-r","--random","Random generation of the skipblock's height (with maximum height specified with -i") do |r|
        @options[:random] = true
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
    @options[:processor]= ARGV.shift.capitalize.to_sym
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
        ## first get the list of snapshots
        snaps = mockup.snapshots @options[:snap_head]
        @options[:base].each do |b|

            @options[:height].each do |h|
                config = Skipchain::Config.new(b,h,@options[:random])
                ## construct the skiplist out of it
                skiplist = Skipchain::create_skiplist snaps, config
                ## fetch and map the client updates
                updates = mockup.client_updates skiplist.mapping_client_update(),@options[:client_head]

                ## run the processor
                result  = Processor::process @options[:processor],mockup,updates, skiplist,@options

                puts "[+] Processing with base #{b} & height #{h} terminated"

                ## write to file
                name = format_name @options[:out],b,h
                File.open(name,"w+") do |f|
                    columns = (["base","height"] + result.shift).join(", ")  + "\n"
                    f.write columns
                    result.first.each do |values|
                        f.write ([b,h] + values).join(", ") + "\n"
                    end
                end
                puts "[+] Results written to #{name}"
            end 
        end
    end
end

## return file name in the form /path/to/file/file_b**_h**.ext
def format_name name, base,height
    fname = File.basename(name,File.extname(name))
    dirname = File.dirname(name)
    new = fname + "_b#{base}_h#{height}#{File.extname(name)}"
    File.join(dirname,new)
end

args
main
