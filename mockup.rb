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
    PACKAGES_PATH = SNAPSHOT_PATH + "packages/"
    LOCAL_PACKAGES_SIZE = "packages_size.txt"
    REMOTE_USER_FILE= "/root/tuf-client/sorted.packages.log.4.ts-ip"
    LOCAL_USER_FILE = "sorted_user.ts-ip.log"

    @@aborting = lambda { abort("[-] Not connected to server") }

    def initialize
        @ssh = nil
        @packages = {}
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
                           output.lines.each do |fname|
                               time = fname.match(/snapshot\.(.*)\.json/)[1]
                               snapshots << Struct::Snapshot.new(time.to_i,fname.chomp)
                           end
                           puts "[+] #{snapshots.size} snapshots retrieved from server"
                           snapshots 
                       end
    end

    ## retrieve the client updates info, stores it locally
    ## you need to give a function that returns the correct timestamp
    ## normally that would be the one nearest from an update
    def client_updates mapping = nil
        mapping = lambda { |x| x } if mapping.nil?
        ## check if already downloaded
        processor = Proc.new do
            abort("[-] Client file not downloaded.") unless File.exists? LOCAL_USER_FILE
            ## hash[ip] = timestamps
            clientsMap = Hash.new { |h,k| h[k] = [] }
            countUpdate = 0
            File.open(LOCAL_USER_FILE,"r") do |f|
                f.each_line do |line|
                    time, ip = line.gsub(" ","").chomp.split ","
                    time = mapping.call(time.to_i)
                    clientsMap[ip.gsub(" ","").chomp] << time
                    countUpdate += 1
                end
                puts "[+] Retrieved #{clientsMap.keys.size} clients with #{countUpdate} updates"
            end 
           # puts "CLIENT FILE # LINES => #{File.readlines(LOCAL_USER_FILE).size}"
            next clientsMap
        end
        return processor.call if File.exist? LOCAL_USER_FILE
        ## otherwise download it
        Net::SCP.download!(HOST,USER,REMOTE_USER_FILE,LOCAL_USER_FILE)
        return processor.call
    end


    ## get_packages_size will load the sizes of all packages/* in memory
    def packages_size
        @@aborting.call if @ssh.nil?
        pr = Proc.new do
            File.foreach(LOCAL_PACKAGES_SIZE) do |line|
                name,size = line.chomp.split
                @packages[name] = size.to_i
            end
        end

        if !File.exists? LOCAL_PACKAGES_SIZE 
            cmd = "cd #{PACKAGES_PATH} && ls | xargs stat -c '%n %s'"
            output = @ssh.exec!(cmd)
            File.open(LOCAL_PACKAGES_SIZE,"w") { |f| f.write output }
        end

        pr.call
        puts "[+] Fetched size of all #{@packages.length} packages"
        @packages
    end

    ## get_diff_size returns the difference between snap1 and snap2 in terms of
    #  packages that must be updated (i.e. downloaded) => returns # bytes
    #  NOTE: snap1.timestamp < snap2.timestamp
    def get_diff_size s1,s2
        name1,name2 = s1.name,s2.name
        @@aborting.call unless @ssh                
        ## get the diff 
        diffCmd = "diff -dbwB --unified=0 --suppress-common-lines #{name1} #{name2} | grep -E '^\+.*packages'"
        cmd = "cd #{SNAPSHOT_PATH} && #{diffCmd}" 
        out = @ssh.exec!(cmd)
        abort("[-] Error diffing: " + out) if cmd =~ /diff: /

        #countCmd = "cd #{SNAPSHOT_PATH} && diff -dbwB --unified=0 --suppress-common-lines #{name1} #{name2} | grep -E '^\+.*packages' | uniq -u | wc -l"
        #puts "#{name1} vs #{name2} => #{@ssh.exec!(countCmd).chomp} vs LOCAL #{out.lines.count}"
        #puts "DiffCommand = #{diffCmd}"
        #puts "CountCommand = #{countCmd}"

        ## analyze the diff
        out.lines.inject(0) do |sum,line|
            name,hash = line.split ":"
            m = name.match(/packages\/(.+)\.json/)
            puts "cmd #{cmd} \nout = #{out}" if m.nil?
            name = m[1]
            hash = hash.match(/([a-f0-9]+)/)[1]
            fname = name+"."+hash+".json"
            sum += @packages[fname]
        end
    end

end
