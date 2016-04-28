## module skpichain contains definition for a skipblock and methods to create /
#simulate a skipchain out of the tuf data
module Skipchain

    ## skipblock as a unit
    class Skipblock
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
    end

    ## thie whole skiplist (contains every skipblock)
    class Skiplist 
        def initialize skipblocks
            @skipblocks = skipblocks
        end

        def to_s 
            @skipblocks.each_with_index.inject("") do |sum,(blk,i)| 
                sum += i.to_s + "\t: " + blk.to_s + "\n"
                sum += "\t: |\n"
            end
        end
    
        ## map_client_update returns a function to map the timestamp of the client updates to the
        #nearest one from the skipblocks
        def mapping_client_update 
            last_id = 0
            size = @skipblocks.size
            Proc.new do |ts|
                last_ts = @skipblocks[last_id].timestamp
                last_id.upto(size-1).each do |id| 
                    block = @skipblocks[id]
                    ## if its the last then returns this one
                    next block.timestamp if id == size-1

                    ## otherwise check the next one in the list
                    nextBlock = @skipblocks[id+1]
                    diff = (ts-nextBlock.timestamp)
                    if diff < 0  
                        last_id = id
                        next block
                    end
                end
            end
        end

    end 

    ## a skipchain has a fixed base and a fixed maximum height
    # head is if you want only to generate the skiplist for *head* snapshots
    Config = Struct.new("Config",:base,:height,:head)

    ## return a skiplist  out of the list of snapshots and the config
    def self.create_skiplist snapshots, config
        ## compute the table of b^(i-1) for 0 <= i <= h
        #  [ [ b^i-1 ] , i (height-1)]
        table = (config.height-1).downto(0).map { |i| [config.base**i,i] }
        ## take the one we want
        snapshots = snapshots.first(config.head) if config.head
        ## create the blocks
        blocks = snapshots.each_with_index.map do |snap,i| 
            entry = table.find{ |k,v| i % k == 0 }
            Skipblock.new snap,entry[1]+1
        end
        Skiplist.new blocks
    end

    

end



