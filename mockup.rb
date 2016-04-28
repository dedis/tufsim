require 'net/ssh'
require 'net/scp'

## define snapshot  info struct, name is the filename
Struct.new("Snapshot",:timestamp,:name)

## define client update info struct
Struct.new("ClientUpdate",:ip,:timestamps)

class Mockup

    HOST = "icsil1-conode1"
    USER = "root"
    SNAPSHOT_PATH = "/root/tuf/"
    REMOTE_USER_FILE= "/root/tuf-client/sorted.packages.log.4.ts-ip"
    LOCAL_USER_FILE = "sorted_user.ts-ip.log"

    def initialize
        @ssh = nil
    end

    def connect
        print "[+] Connecting to server..."
        @ssh = Net::SSH.start(HOST,USER) 
        print "OK\n"
    end

    def close
        print "[+] Closing connection to server..."
        @ssh.close
        print "OK\n"
    end

    ## retrieve the snapshots info from the 23.5gb compressed files hosted on our server
    def snapshots
        abort("[-] Not connected to server") if @ssh.nil?
        @snapshots ||= begin
            snapshots = []
            output = ""
            ## print the size and shorten the name to only the timestamp
            cmd = "cd #{SNAPSHOT_PATH} && " + 'ls *json' # sed "s/snapshot\.\(.*\)\.json/\1/"'
            output = @ssh.exec!(cmd)
            #special treatment because of the firs directory "packages"

            ## populate the list of snapshots
            output.each_line do |fname|
                time = fname.match(/snapshot\.(.*)\.json/)[1]
                snapshots << Struct::Snapshot.new(time.to_i,fname)
            end
            puts "[+] #{snapshots.size} snapshots retrieved from server"
            snapshots 
        end
    end

    ## retrieve the client updates info, stores it locally
    ## you need to give a function that returns the correct timestamp
    ## normally that would be the one nearest from an update
    def client_updates mapping
        ## check if already downloaded
        processor = Proc.new do
            abort("[-] Client file not downloaded.") unless File.exists? LOCAL_USER_FILE
            ## hash[ip] = timestamps
            clientsMap = Hash.new { |h,k| h[k] = [] }
            countUpdate = 0
            clients = File.foreach(LOCAL_USER_FILE).map do |line|
                time, ip = line.split ","
                time = mapping.call(time.to_i)
                clientsMap[ip] << time
                countUpdate += 1
            end 
            puts "[+] Retrieved #{clientsMap.size} clients with #{countUpdate} updates"
            clients
        end
        return processor.call if File.exist? LOCAL_USER_FILE
        ## otherwise download it
        Net::SCP.download!(HOST,USER,REMOTE_USER_FILE,LOCAL_USER_FILE)
        return processor.call
    end

end
