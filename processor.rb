module Processor

    ## signature 
    SIG_SIZE = 156

    class << self
        attr_accessor :cache_diff
    end
    self.cache_diff = {}

    ## generic processor launcher
    def self.process klass, mockup,updates, skiplist
        klass = klass.capitalize.to_sym if klass.is_a?(String)
        processor = Processor::const_get(klass).new mockup,updates,skiplist
        processor.process
    end
            


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
            puts "[+] Processing done for #{perc} %" if perc % 1.0 == 0.0
            #puts "[+] Treating client #{count}/#{@updates.size} with #{tss.size} timestamps"
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
        h
    end

    def flatten hash
        ## then flatten out the results
        cumul = 0
        hash.keys.each do |k|
            sum = hash[k].inject(0) { |sum,ts| sum += ts } + cumul
            hash[k] = sum
            cumul = sum
        end
        h
    end

    class Generic

        include Processor

        def initialize mockup,updates,skiplist
            @mockup = mockup
            @updates = updates
            @skiplist = skiplist
        end

    end

    ## OneLevel process skipblock at the level 0
    ## -> simulation of a client that must retrieve every skipblock until the
    #right one on the level 0
    class Level0 < Processor::Generic

        def process
            puts "[+] OneLevel processor starting"
            res = process_block do  |base_snap, next_snap|
                ## size of all the new packages that must have been
                #downloaded
                bytes = get_diff base_snap,next_snap
                ## # of skipblocks that must be traversed between the two
                # 0-level
                blocks = @skiplist.timestamps[next_snap.timestamp] - @skiplist.timestamps[base_snap.timestamp]
                total = bytes + blocks * SIG_SIZE
                total
            end
            puts "[+] OneLevel processor finished getting the diff"
            flatten res
        end
    end

end
