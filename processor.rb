module Processor

    class << self
        attr_accessor :cache_diff
    end
    self.cache_diff = {}

    ## generic processor launcher
    def self.process klass, mockup,updates, skiplist,options
        begin
            klass = klass.capitalize.to_sym if klass.is_a?(String)
            processor = Processor::const_get(klass).new mockup,updates,skiplist,options
        rescue Exception => e
            puts("[-] Processing module not known. Abort. (#{e})")
            abort
        end
        puts "[+] #{klass} starting to process" if options[:v]
        res = processor.process
        puts "[+] #{klass} finished processing" if options[:v]
        res
    end

    class Generic

        COLUMN_HEIGHT = :height
        COLUMN_TIME = :time

        DEFAULT_COLUMNS = [COLUMN_HEIGHT,COLUMN_TIME]

        include Processor

        require_relative 'ruby_util'
        require 'etc'
        require 'thread'

        def initialize mockup,updates,skiplist,options
            @mockup = mockup
            @updates = updates
            @skiplist = skiplist
            @options = options
            @diff_cache = {}
            @mutex = Mutex.new
        end

        def name
            if @options[:processor] == :All 
                "bw_#{@options[:graph]}_" + RubyUtil::demodulize(self.class.name.downcase)
            else
                "bandwidth"
            end
        end

        ## returns the diff in bytes between two snapshots
        def get_diff s1,s2
            @mutex.synchronize {
                key = "#{s1.name}:#{s2.name}"
                if Processor.cache_diff[key] == nil
                    Processor.cache_diff[key] = @mockup.get_diff_size s1,s2
                end
                Processor.cache_diff[key]
            }
        end

        ## function to call to process all the timestamps of clients
        def process_block &block
            @options[:threads] ? process_block_threading(&block): process_block_mono(&block)
        end

        ## process_block using threads
        def process_block_threading &block

            h = Hash.new { |h,k| h[k] = [] }
            procs = Etc.nprocessors
            threads = []
            RubyUtil::slice @updates.keys, procs do |ips,i|
                puts "[+] Starting new thread ##{i} with #{ips.inject(0){ |acc,ip| acc += @updates[ip].size}} updates for #{ips.size} clients" if @options[:v]
                threads << Thread.new do 
                    Thread.current[:thread] = i
                    res = process_block_ips ips, &block
                    Thread.current[:res] = res
                end
            end
            puts "[+] Use of #{procs} (#{threads.size}) threads (# processors)" if @options[:v]
            threads.each do |t|
                t.join
                h.merge!(t[:res]) { |k,old,new| old + new }
            end
            h = Hash[h.sort]
            format_data h
        end

        ## process_block using one thread
        def process_block_mono &block
            res = process_block_ips @updates.keys, &block
            res = Hash[res.sort]
            format_data res
        end


        ## process_block_ips takes the list of client IP to anaylze and 
        #returns hashmap with
        ## KEYS => timestamp of snapshots 
        #  VALUES => cumulative bandwitdth consumption by clients
        def process_block_ips ips
            ## hash containing all values for all clients per timestamp that will
            #be averaged at the end
            # Key => timestamp of snapshosts
            # Value => list of #bytes that have been downloaded by each client
            # that retrieved this snapshot
            h = Hash.new { |h,k| h[k] = [] }

            # lets go over one client at a time  
            count = 0
            ips.each do |ip|
                tss = @updates[ip]
                count += 1
                perc = (count.to_f / ips.size.to_f * 100.0)
                ok = perc == perc.round && perc.round % 25 == 0
                if ok && @options[:v]
                    if Thread.current[:thread]
                        puts "[+] Thread #{Thread.current[:thread]} processed #{perc} % of its data" 
                    else
                        puts "[+] Processing done for #{perc} %" if perc % 25 == 0 if @options[:v]
                    end
                end
                #puts "[+] Treating client #{count}/#{@updates.size} with #{tss.size} timestamps" if @options[:v]
                next if tss.size == 1
                ## let's calculate each diff
                base_ts = tss.first
                tss.each_with_index do |ts,i|
                    next_ts = ts 
                    if next_ts == base_ts
                        #puts "#{ip} No new updates"
                        #puts "client #{ip}=>baseid #{@skiplist.timestamps[base_ts]} vs nextid #{@skiplist[next_ts]} vs length of id #{@skiplist.skipblocks.size}"
                        next
                    end
                    base_snap = @skiplist[base_ts]
                    next_snap = @skiplist[next_ts]

                    total = yield base_snap, next_snap
                    key = @options[:graph] == :cumulative ? next_ts : next_ts - base_ts
                    h[key] << total
                    base_ts = next_ts
                end
            end  
            h
        end

        def format_data hash
            puts "[+] #{hash.keys.size} distinct client updates timestamp found" if @options[:v]
            case @options[:graph]
            when :cumulative
                flatten hash
            when :scatter
                scatter hash
            end
        end

        def default_values time
            [@skiplist.height,time]
        end 

        ## scatter will return one row per update of clients
        def scatter hash
            res = hash.inject([]) do |acc,(time,values)|
                values.each { |v| acc << (default_values(time) << v) } 
                acc
            end
            [DEFAULT_COLUMNS + [name], res]
        end

        ## flatten out results by taking the cumulative bandwidth for each timestamp
        ## returns something that can be written directly to csv
        ## (columns, data) where
        ## columns => array of columns names
        ## data => array of rows in the final csv file, i.e. array of arrays
        # [ [column1_data1,column2_data1], [column1_data2,column2_data2]]
        def flatten hash
            ## then flatten out the results
            cumul = 0
            values = values = hash.inject([]) do |acc, (time,values) |
                sum = values.inject(0) { |sum,bw| sum += bw }
                cumul += sum
                acc << (default_values(time) << values.size << cumul)
            end
            [DEFAULT_COLUMNS + [:updates,name], values]
        end

    end

    ## OneLevel process skipblock at the level 0
    ## -> simulation of a client that must retrieve every skipblock until the
    #right one on the level 0
    class Height0 < Processor::Generic

        def process
            res = process_block do  |base_snap, next_snap|
                ## size of all the new packages that must have been
                #downloaded
                bytes = get_diff base_snap,next_snap
                ## # of skipblocks that must be traversed between the two
                # 0-level
                blocks = @skiplist.timestamps[next_snap.timestamp] - @skiplist.timestamps[base_snap.timestamp]
                bytes + blocks * Skipchain::BLOCK_SIZE_DEFAULT
            end
        end
    end

    ##
    class Tuf < Processor::Generic
        def process
            res = process_block do |base_snap, next_snap|
                bytes_diff = 0
                curr_snap = base_snap
                loop do
                    intermediate = @skiplist.next(curr_snap,0)
                    bytes_diff += get_diff curr_snap,intermediate
                    curr_snap = intermediate
                    break if intermediate == next_snap
                end
                bytes_diff
            end
        end
    end

    # Tuf simply analyzes the direct diff between two blocks
    class Diplomat < Processor::Generic
        def process
            res  = process_block do |base_snap, next_snap|
                # simply get the diff between the two
                get_diff base_snap,next_snap
            end
        end
    end

    ## Skiplist processor the way skiplist would work 
    ## i.e. find the shortest path in the skiplist from one block to the other
    class Skiplist < Processor::Generic

        def process
            last_ts = @skiplist.skipblocks.last.timestamp
            res = process_block do |base_snap,next_snap|
                curr = base_snap 
                curr_height = curr.height
                bytes_block = 0
                loop do 
                    intermediate = @skiplist.next(curr,curr_height)

                    if intermediate.timestamp  == last_ts
                        bytes_block += @options[:fixed] ? Skipchain::BLOCK_SIZE_DEFAULT : intermediate.size
                        break
                    end
                    ## we went too far
                    if intermediate.timestamp > next_snap.timestamp
                        curr_height -= 1
                        next
                    end

                    curr = intermediate
                    curr_height = curr.height
                    bytes_block += @options[:fixed] ? Skipchain::BLOCK_SIZE_DEFAULT : intermediate.size
                    # we fall on the right block !
                    break if intermediate.timestamp == next_snap.timestamp
                end
                bytes = get_diff base_snap,next_snap 
                bytes + bytes_block
            end
        end
    end


end
