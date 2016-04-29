module Processor

    ## signature size = challenge + response size
    SIG_SIZE = 32 * 2

    class << self
        attr_accessor :cache_diff
    end
    self.cache_diff = {}

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
    ## OneLevel process skipblock at the level 0
    ## -> simulation of a client that must retrieve every skipblock until the
    #right one on the level 0
    class OneLevel
    
        include Processor

        def initialize mockup,updates,skiplist
            @mockup = mockup
            @updates = updates
            @skiplist = skiplist
        end

        ## process returns hashmap with
        ## KEYS => timestamp of snapshots 
        #  VALUES => cumulative bandwitdth consumption by clients
        def process 
            puts "[+] OneLevel processor starting"
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
                puts "[+] OneLevel at #{perc} %" if perc % 1.0 == 0.0
                puts "[+] Treating client #{count}/#{@updates.size} with #{tss.size} timestamps"
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

                    ## size of all the new packages that must have been
                    #downloaded
                    bytes = get_diff base_snap,next_snap
                    ## # of skipblocks that must be traversed between the two
                    # 0-level                    
                    blocks = @skiplist.timestamps[next_ts] - @skiplist.timestamps[base_ts]

                    total = bytes + blocks * SIG_SIZE          
                    h[next_ts] << total
                    base_ts = next_ts
                end
            end  
            puts "[+] OneLevel processor finished getting the diff"

            ## then flatten out the results
            cumul = 0
            h.keys.each do |k|
                sum = h[k].inject(0) { |sum,ts| sum += ts } + cumul
                h[k] = sum
                cumul = sum
            end
            h

        end

    end

end
