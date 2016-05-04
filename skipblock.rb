## module skpichain contains definition for a skipblock and methods to create /
#simulate a skipchain out of the tuf data
module Skipchain

    ## a skipchain has a fixed base and a fixed maximum height
    # head is if you want only to generate the skiplist for *head* snapshots
    Config = Struct.new("Config",:base,:height)

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
            0.upto(@height.to_i-1).map{ "O" }.join(" -- ")
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
    end

    ## thie whole skiplist (contains every skipblock)
    class Skiplist 
        attr_reader :timestamps
        attr_reader :skipblocks
        
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

        def last
            @skipblocks.last
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

        def 

        def stringify 
            @skipblocks.each_with_index.inject("") do |sum,(blk,i)| 
                sum += i.to_s + "\t: " + blk.to_s + "\n"
                sum += "\t: |\n"
            end
        end
    
        #def mapping_client_update2
        #    last_id = 0
        #    Proc.new do |ts|
        #        ret_value = nil
        #        @skipblocks[last_id].each_cons(2).each_with_index do |(old,new),i|
        #            
        #        end
        #    end
        #end
        #
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
    end 

    ## return a skiplist  out of the list of snapshots and the config
    def self.create_skiplist snapshots, config
        ## compute the table of b^(i-1) for 0 <= i <= h
        #  [ [ b^i-1 ] , i (height-1)]
        table = (config.height-1).downto(0).map { |i| [config.base**i,i] }
        ## create the blocks
        
        sk = Skipchain::Skiplist.new config.base,config.height
        snapshots.each_with_index.map do |snap,i| 
            entry = table.find{ |k,v| i % k == 0 }
            sk.add snap,entry[1]+1
        end
        puts "[+] Skiplist created out of the snapshots"
        sk
    end

    

end



