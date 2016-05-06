## module skpichain contains definition for a skipblock and methods to create /
#simulate a skipchain out of the tuf data
module Skipchain


    ## a skipchain has a fixed base and a fixed maximum height
    # head is if you want only to generate the skiplist for *head* snapshots
    # random is to create random height for each skipblock.
    class Factory

        def initialize options
            @options = options
        end

        ## each will yield each different skiplist according to the options
        def each snapshots
            if @options[:random]
                heights_base(@options[:random]).each do |h,r|
                    yield create_skiplist_random snapshots,r,h
                end
            else
                heights_base(@options[:base]).each do |h,b|
                    yield create_skiplist_normal snapshots,b,h
                end
            end
        end

        private

        # Extend heights of bases to the same number of elements
        def heights_base params
            h = @options[:height]
            b = params
            if h.size < params.size
                h.push(h.last) while h.size < b.size
            else
                b.push(b.last) while b.size < h.size
            end
            h.zip(b)
        end

        def create_skiplist_random snapshots,random,height
            sk = Skipchain::SkiplistRandom.new random,height
            snapshots.each do |s|
                h = 0
                h += 1 while h < height && rand <= random 
                sk.add s,h
            end 
            puts "[+] Random #{random.round(2)} skiplist created"
            sk
        end

        ## return a skiplist  out of the list of snapshots and the config
        def create_skiplist_normal snapshots, base,height
            ## compute the table of b^(i-1) for 0 <= i <= h
            #  [ [ b^i-1 ] , i (height-1)]
            table = height.downto(0).map { |i| [base**i,i] }
            ## create the blocks
            sk = Skipchain::Skiplist.new base,height
            snapshots.each_with_index.map do |snap,i| 
                entry = table.find{ |k,v| i % k == 0 }
                sk.add snap,entry[1]
            end
            puts "[+] Normal skiplist created"
            sk
        end
    end



    ## signature 
    BLOCK_SIZE_DEFAULT = 156

    ## skipblock as a unit
    class Skipblock
        attr_reader :height
        attr_reader :snapshot

        def initialize snapshot,height
            @snapshot = snapshot
            @height = height
        end

        def to_s 
            #s = @timestamp.to_s + " | " + @size.to_s 
            0.upto(@height.to_i).map{ "O" }.join(" -- ")
        end

        def timestamp
            @snapshot.timestamp
        end

        def name 
            @snapshot.name
        end

        def size
            BLOCK_SIZE_DEFAULT + 128 * @height
        end

        def == sk2
            name == sk2.name && timestamp == sk2.timestamp
        end
    end

    ## thie whole skiplist (contains every skipblock)
    class Skiplist 
        attr_reader :timestamps
        attr_reader :skipblocks
        ## maximum height
        attr_reader :height
        attr_reader :base

        def initialize base,height
            @base = base
            @height = height
            @skipblocks = []
            @timestamps = {}
        end

        def add snapshot,height
            block = Skipblock.new snapshot,height
            @skipblocks << block
            @timestamps[snapshot.timestamp] = @skipblocks.size-1
        end

        def each
            @skipblocks.each
        end

        ## next returns the next snapshot after this one
        ## you can specify a level to get the next snapshot AT THE SPECIFIED
        #level to get faster lookup
        def next snapshot, level = 0
            idx = @timestamps[snapshot.timestamp]
            offset = @base ** level 
            return @skipblocks.last if idx+offset > @skipblocks.size-1
            nblock = @skipblocks[idx+offset]
            abort("Something wrong here?") if nblock.height < level
            #puts "[+] Next block Skipped #{offset} blocks" 
            nblock
        end

        ## accessor using timestamps
        def [](timestamp)
            idx = @timestamps[timestamp] 
            abort("[-] Timestamp not known ?") unless idx
            @skipblocks[idx]
        end


        def stringify 
            @skipblocks.each_with_index.inject("") do |sum,(blk,i)| 
                sum += i.to_s + "\t: " + blk.timestamp.to_s + "\t" + blk.to_s + "\n"
                sum += "\t: \t|\n"
            end
        end

        ## map_client_update returns a function to map the timestamp of the client updates to the
        #nearest one from the skipblocks
        def mapping_client_update 
            last_id = 0
            size = @skipblocks.size
            return Proc.new do |ts|
                ret_value = @skipblocks[last_id].timestamp
                last_id.upto(size-1).each do |id| 
                    block = @skipblocks[id]
                    ## if its the last then returns this one
                    ## or if it's the first and it's already bigger than the
                    #client update time
                    if id == size-1 || block.timestamp > ts
                        ret_value = block.timestamp
                        break
                    end

                    ## otherwise check the next one in the list
                    nextBlock = @skipblocks[id+1]
                    diff = (ts-nextBlock.timestamp)
                    if diff < 0  
                        last_id = id
                        ret_value = block.timestamp
                        break
                    end
                end
                ret_value
            end
        end

        def to_s
            "Skiplist (deterministic): base = #{base}, height = #{height}"
        end
    end

    class SkiplistRandom < Skiplist

        attr_reader :random

        def initialize random,height
            super(nil,height)
            @random = random
        end

        def next snapshot, level = 0
            if level == 0
                return @skipblocks[@timestamps[snapshot.timestamp]+1] ||
                    @skipblocks.last
            end
            oldi = @timestamps[snapshot.timestamp] + 1
            @skipblocks[oldi..-1].find { |s| s.height >= level}  || @skipblocks.last
        end

        def to_s
            "Skiplist (random): random = #{@random.round(2)}, height = #{height}"
        end

    end

end
