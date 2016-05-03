
## define snapshot  info struct, name is the filename
Struct.new("Snapshot",:timestamp,:name)

## define client update info struct
Struct.new("ClientUpdate",:ip,:timestamps)


module Mockup
    HOST = "icsil1-conode1"
    USER = "root"
    SNAPSHOT_PATH = "/root/tuf/"
    PACKAGES_PATH = SNAPSHOT_PATH + "packages/"
    LOCAL_PACKAGES_SIZE = "packages_size.txt"
    REMOTE_USER_FILE= "/root/tuf-client/sorted.packages.log.4.ts-ip"
    LOCAL_USER_FILE = "sorted_user.ts-ip.log"


    @@aborting = lambda { abort("[-] Not connected to server") }

    ## store in memory the size of all packages metadata file
    ## Give it a block that receives the command and execute it (locally or
    #  whatever)
    def compute_packages_size 
        cmd = "cd #{PACKAGES_PATH} && ls | xargs stat -c '%n %s'"
        output = yield cmd
        @packages = {}
        output.each_line do |line|
            name,size = line.chomp.split
            @packages[name] = size.to_i
        end
        puts "[+] Fetched size of all #{@packages.length} packages"
        @packages
    end

    def compute_snapshots_list head = nil
        @snapshots ||= begin
                           snapshots = []
                           output = ""
                           ## print the size and shorten the name to only the timestamp
                           cmd = "cd #{SNAPSHOT_PATH} && " + 'ls *json' # sed "s/snapshot\.\(.*\)\.json/\1/"'
                           output = yield cmd
                           ## populate the list of snapshots
                           snapshots = []
                           output.each_line.each_with_index do |fname,i|
                               next if head && i > head
                               time = fname.match(/snapshot\.(.*)\.json/)[1]
                               snapshots << Struct::Snapshot.new(time.to_i,fname.chomp)
                           end
                           puts "[+] #{snapshots.size} snapshots retrieved from server"
                           snapshots
                       end
    end

    ## store in memory the update of all clients
    def analyze_client_update_file  fname, mapping, head = nil
        @clientsMap ||=
            begin
                abort("[-] Client log file absent.") unless File.exists? fname
                ## hash[ip] = timestamps
                clientsMap = Hash.new { |h,k| h[k] = [] }
                countUpdate = 0
                File.foreach(fname) do |line|
                    next if head && countUpdate > head    
                    time, ip = line.gsub(" ","").chomp.split ","
                    time = mapping.call(time.to_i)
                    clientsMap[ip.gsub(" ","").chomp] << time
                    countUpdate += 1
                end
                before = countUpdate
                clientsMap.inject(clientsMap) do |h,(k,v)| 
                    next h unless v.size == 1 
                    countUpdate -= 1
                    h.delete(k)
                    next h
                end 
                puts "[+] Retrieved #{clientsMap.size} clients with #{countUpdate}/#{before} updates"
                clientsMap
            end
    end

    def mockup_get_diff_size s1,s2
        name1,name2 = s1.name,s2.name
        ## get the diff 
        diffCmd = "diff -dbwB --unified=0 --suppress-common-lines #{name1} #{name2} | grep -E '^\+.*packages'"
        cmd = "cd #{SNAPSHOT_PATH} && #{diffCmd}" 
        out = yield cmd
        abort("[-] Error diffing: " + out) if cmd =~ /diff: /

        #countCmd = "cd #{SNAPSHOT_PATH} && diff -dbwB --unified=0 --suppress-common-lines #{name1} #{name2} | grep -E '^\+.*packages' | uniq -u | wc -l"
        #puts "#{name1} vs #{name2} => #{@ssh.exec!(countCmd).chomp} vs LOCAL #{out.lines.count}"
        #puts "DiffCommand = #{diffCmd}"
        #puts "CountCommand = #{countCmd}"

        ## analyze the diff
        out.lines.inject(0) do |sum,line|
            name,hash = line.split ":"
            m = name.match(/packages\/(.+)\.json/)
            abort "cmd #{cmd} \nout = #{out}" if m.nil?
            name = m[1]
            hash = hash.match(/([a-f0-9]+)/)[1]
            fname = name+"."+hash+".json"
            sum += @packages[fname]
        end
    end

    def initialize opts
        @options = opts
    end

    class Local
        include Mockup

        def snapshots head = nil
            compute_snapshots_list(head) { |cmd| `#{cmd}` }
        end
        ## retrieve the client updates info, stores it locally
        ## you need to give a function that returns the correct timestamp
        ## normally that would be the one nearest from an update
        def client_updates mapping = nil,head = nil
            mapping = lambda { |x| x } if mapping.nil?
            ## check if already downloaded
            abort ("[-] No user log file") unless File.exist? REMOTE_USER_FILE
            return analyze_client_update_file(REMOTE_USER_FILE, mapping,head)
        end

        def packages_size
            compute_packages_size { |cmd| `#{cmd}` }
        end

        ## get_diff_size returns the difference between snap1 and snap2 in terms of
        #  packages that must be updated (i.e. downloaded) => returns # bytes
        #  NOTE: snap1.timestamp < snap2.timestamp
        def get_diff_size s1,s2
            mockup_get_diff_size(s1,s2) { |cmd| `#{cmd}` } 
        end



    end

    class SSH
        require 'net/ssh'
        require 'net/scp'

        include Mockup

        def connect
            print "[+] Connecting to server..." if @options[:v]
            @ssh = Net::SSH.start(HOST,USER) 
            print "OK\n" if @options[:v]
        end

        def close
            print "[+] Closing connection to server..." if @options[:v]
            @ssh.close
            print "OK\n" if @options[:v]
        end

        ## retrieve the snapshots info from the 23.5gb compressed files hosted on our server
        def snapshots head
            abort("[-] Not connected to server") if @ssh.nil?
            compute_snapshots_list(head) do |cmd| 
                out = @ssh.exec!(cmd) 
                out
            end
        end

        ## retrieve the client updates info, stores it locally
        ## you need to give a function that returns the correct timestamp
        ## normally that would be the one nearest from an update
        def client_updates mapping = nil,head = nil
            mapping = lambda { |x| x } if mapping.nil?
            ## check if already downloaded

            return analyze_client_update_file(LOCAL_USER_FILE, mapping,head) if File.exist? LOCAL_USER_FILE
            ## otherwise download it
            puts "[+] SSH - downloading client log"
            Net::SCP.download!(HOST,USER,REMOTE_USER_FILE,LOCAL_USER_FILE)
            return analyze_client_update_file(LOCAL_USER_FILE,mapping,head)
        end

        ## packages_size will load the sizes of all packages/* in memory
        def packages_size
            @@aborting.call if @ssh.nil?
            compute_packages_size do |cmd|
                output = @ssh.exec!(cmd)
            end
        end

        ## get_diff_size returns the difference between snap1 and snap2 in terms of
        #  packages that must be updated (i.e. downloaded) => returns # bytes
        #  NOTE: snap1.timestamp < snap2.timestamp
        def get_diff_size s1,s2
            @@aborting.call unless @ssh                
            mockup_get_diff_size s1,s2 do |cmd|
                @ssh.exec!(cmd) 
            end
        end

    end
end
