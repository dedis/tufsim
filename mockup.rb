require 'net/ssh'

## define snapshot  info struct
Struct.new("Snapshot",:timestamp,:size)

## define client update info struct
Struct.new("ClientUpdate",:timestamp,:snapshot)

module Mockup

    HOST = "icsil1-conode1"
    USER = "root"
    SNAPSHOT_PATH = "/root/tuf/"
    USER_FILE= "~/tuf-client/sorted.packages.log.4.ts-ip"

    ## retrieve the snapshots info from the 23.5gb files hosted on our server
    def self.snapshots
        snapshots = []
        output = ""
        print "[+] Connecting to server to retrieve snapshots..."
        Net::SSH.start(HOST,USER) do |ssh|
            ## print the size and shorten the name to only the timestamp
            cmd = "cd #{SNAPSHOT_PATH} && " + 'stat -c "%s %n" * | sed "s/snapshot\.\(.*\)\.json/\1/"'
            output = ssh.exec!(cmd)
        end
        ## populate the list of snapshots
        output.each_line do |line|
            size, time = line.split
            snapshots << Struct::Snapshot.new(time,size)
        end
        puts " #{snapshots.size} snapshots retrieved."
        snapshots 
    end

    ## retrieve the client updates info
    def client_updates

    end

end
