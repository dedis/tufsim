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

        include Processor

        require_relative 'ruby_util'

        def initialize mockup,updates,skiplist,options
            @mockup = mockup
            @updates = updates
            @skiplist = skiplist
            @options = options
        end

        def name
            RubyUtil::demodulize self.class.name.downcase
        end

        ## returns the diff in bytes between two snapshots
        def get_diff s1,s2
            base_ts = s1.timestamp
            next_ts = s2.timestamp
            if Processor.cache_diff.key?([base_ts,next_ts])
                bytes = Processor.cache_diff[[base_ts,next_ts]]
            else
                bytes = @mockup.get_diff_size s1,s2 
                Processor.cache_diff[[base_ts,next_ts]] = bytes
            end
            bytes
        end
    
        ## process returns hashmap with
        ## KEYS => timestamp of snapshots 
        #  VALUES => cumulative bandwitdth consumption by clients
        def process_block
            ## hash containing all values for all clients per timestamp that will
            #be averaged at the end
            # Key => timestamp of snapshosts
            # Value => list of #bytes that have been downloaded by each client
            # that retrieved this snapshot
            h = Hash.new { |h,k| h[k] = [] }

            # lets go over one client at a time  
            count = 0
            @updates.each do |ip,tss|
                count += 1
                perc = count.to_f / @updates.size.to_f * 100.0
                puts "[+] Processing done for #{perc} %" if perc % 1.0 == 0.0 if @options[:v]
                #puts "[+] Treating client #{count}/#{@updates.size} with #{tss.size} timestamps" if @options[:v]
                next if tss.size == 1
                ## let's calculate each diff
                base_ts = tss.first
                tss.each do |ts|
                    next_ts = ts 
                    if next_ts == base_ts
                        #puts "#{ip} No new updates"
                        #puts "client #{ip}=>baseid #{@skiplist.timestamps[base_ts]} vs nextid #{@skiplist[next_ts]} vs length of id #{@skiplist.skipblocks.size}"
                        next
                    end
                    base_snap = @skiplist[base_ts]
                    next_snap = @skiplist[next_ts]

                    total = yield base_snap, next_snap

                    h[next_ts] << total
                    base_ts = next_ts
                end
            end  
            puts "[+] #{h.keys.size} distinct client updates timestamp found" if @options[:v]
            Hash[h.sort]
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
                sum = values.inject(0) { |sum,bw| sum += bw } + cumul
                cumul += sum
                acc << [time,sum]
            end
            [[:time,"bw_#{name}"], values]
        end


    end

    ## OneLevel process skipblock at the level 0
    ## -> simulation of a client that must retrieve every skipblock until the
    #right one on the level 0
    class Level0 < Processor::Generic

        def process
            res = process_block do  |base_snap, next_snap|
                ## size of all the new packages that must have been
                #downloaded
                bytes = get_diff base_snap,next_snap
                ## # of skipblocks that must be traversed between the two
                # 0-level
                blocks = @skiplist.timestamps[next_snap.timestamp] - @skiplist.timestamps[base_snap.timestamp]
                total = bytes + blocks * Skipchain::BLOCK_SIZE_DEFAULT
                total
            end
            flatten res
        end
    end


    # Tuf simply analyzes the direct diff between two blocks
    class Tuf < Processor::Generic
        def process
            res  = process_block do |base_snap, next_snap|
                # simply get the diff between the two
                get_diff base_snap,next_snap
            end
            flatten res
        end
    end

    ## Skiplist processor the way skiplist would work 
    ## i.e. find the shortest path in the skiplist from one block to the other
    class Skiplist < Processor::Generic

        def process
            res = process_block do |base_snap,next_snap|
                curr = base_snap 
                curr_height = curr.height
                bytes_block = 0
                loop do 
                    intermediate = @skiplist.next(curr,curr_height)

                    ## we went too far
                    if intermediate.timestamp > next_snap.timestamp
                        curr_height -= 1
                        next
                    end

                    curr = intermediate
                    curr_height = curr.height
                    bytes_block += intermediate.size 
                    # we fall on the right block !
                    break if intermediate.timestamp == next_snap.timestamp
                end
                bytes = get_diff base_snap,next_snap 
                bytes + bytes_block
            end
            flatten res
        end
    end

    ## Linear regroups Level0, Tuf and Skiplist
    class Linear < Processor::Generic
        require 'set'
        def process
            columns = Set.new
            values = ["Tuf","Level0","Skiplist"].inject([]) do |acc, p|
                results = Processor::process p, @mockup,@updates, @skiplist, @options
                columns.merge results.shift 
                ## take all but the first data (which is the time,only the first
                #time)
                results.first.each_with_index do |row,i| 
                    time = row.shift; 
                    acc[i] = [time] if acc[i].nil?
                    acc[i] += row
                end
                acc
            end
            [columns.to_a,values]
        end
    end
end
