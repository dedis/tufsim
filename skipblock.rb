## module skpichain contains definition for a skipblock and methods to create /
#simulate a skipchain out of the tuf data
module Skipchain

    ## skipblock as a unit
    class Skipblock
        def initialize timestamp,data_size,height
            @timestamp = timestamp
            @size = data_size
            @height = height
        end

    end

    ## thie whole skiplist (contains every skipblock)
    class Skiplist 
        def initialize skipblocks
            @skipblocks = skipblocks
        end
    end 

    ## a skipchain has a fixed base and a fixed maximum height
    Struct.new("Config",:base,:height)

    ## return a skiplist  out of the list of snapshots and the config
    def create_skiplist snapshots, config

    end
end



