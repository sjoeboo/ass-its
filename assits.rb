
#
require 'rubygems'
require 'json'
require 'yaml'
require "redis"
require 'pp'



$redis_host="redis01"

def asset_load()
        redis=Redis.new(:host => $redis_host)
        keys=redis.keys("*")
        if keys.include?("assets")
                assets=JSON.parse(redis.get("assets"))
        else
                assets=Array.new
        end

        return(assets)
end

def asset_save(assets)
        redis=Redis.new(:host => $redis_host)
        redis.set "assets", assets.to_json
        #need a return here...
end


def new_asset(name,serial=nil,po=nil,dc=nil,rack=nil,top_ru=nil,bot_ru=nil)
        #figure out size
        size=size_calc(top_ru,bot_ru)
        asset={"name"=>name,"serial"=>serial,"po"=>po,"dc"=>dc,"rack"=>rack,"top_ru"=>top_ru,"bot_ru"=>bot_ru,"size"=>size}
        asset=update_stamp(asset)
        return asset
end

def add_asset(asset,assets)
        assets.push(asset)
        return assets
end

def update_stamp(asset)
  time=Time.now
  asset["last_updated"]=time.to_s
  return(asset)
end
def add_comp(asset,name,serial=nil,po=nil,dc=nil,rack=nil,top_ru=nil,bot_ru=nil)
        #make some assumptions if we didn't get info
        #if dc/rack/top_ru/bot_ru are empty, get them from the parent asset
        #likewise for po
        if po==nil
                po=asset["po"]
        end
        if dc==nil
                dc=asset["dc"]
        end
        if rack==nil
                rack=asset["rack"]
        end
        if top_ru==nil
                top_ru=asset["top_ru"]
        end
        if bot_ru==nil
                bot_ru=asset["bot_ru"]
        end

        #if ru's were given figure out size
        #
        size=size_calc(top_ru,bot_ru)

        comp = {"name"=>name,"serial"=>serial,"po"=>po,"dc"=>dc,"rack"=>rack,"top_ru"=>top_ru,"bot_ru"=>bot_ru,"size"=>size}
        if asset.has_key?("components")
                asset["components"].push(comp)
        else
                asset["components"]=Array.new
                asset["components"].push(comp)
        end
        asset=update_stamp(asset)
        return(asset)
end

def size_calc(top_ru,bot_ru)
        if ((top_ru!=nil and bot_ru!=nil) and (top_ru !~ /:/ and bot_ru !~ /:/))
                size=(top_ru.to_i - bot_ru.to_i) + 1
                if size < 0
                        size=size*(-1)
                end
        else
                size = nil
        end
        return (size)
end
def find_asset(assets,field,name)
        results=Array.new
        assets.each do |a|
                if (a[field] =~ /#{name}/i) != nil
                        results.push(a)
                end
        end
        if results.length == 0
                puts "No matches found"
        else
                return(results)
        end

end

def find_component(assets,field,name)
        results=Array.new
        assets.each do |a|
                if a.has_key?("components")
                        a["components"].each do |c|
                                if (c[field] =~ /#{name}/i) != nil
                                        results.push(a)
                                end
                        end
                end
        end
        if results.length == 0
                puts "No matches found"
        else
                return(results)
        end
end

def asset_duplicate_check(asset,assets)
        match=0
        assets.each do |a|
                if a["name"].casecmp(asset["name"]) == 0
                        match =+ 1
                end
        end
        if match == 0
                return true #no matches
        else
                return false #matches
        end
end

def print_help_main()
        puts "Usage: #{$0} <option>"
        puts "Where option is one of:"
        puts ""
        puts "add: add an asset"
        puts "list: list all assets"
        puts "search: search for an asset by name/serial/po"
        puts "modify: modify an asset"
        puts "component: component operations, see #{$0} component help"
        puts "delete: delete an asset"
        puts "export: export full list of assets in a few formats"
        puts "import: assets in a few formats"
end

def sort_assets(assets)
        return (assets.sort_by { |a| a["name"] })
end

def print_assets(assets)
        assets.each do |a|
                puts "---"
                puts "#{a["name"]}"
                puts "  Updated:	#{a['last_updated']}"
		puts "  Serial: 	#{a['serial']}"
                puts "  PO:     	#{a['po']}"
                puts "  DC:     	#{a['dc']}"
                puts "  Rack:   	#{a['rack']}"
                puts "  Top_RU: 	#{a['top_ru']}"
                puts "  Bot_RU: 	#{a['bot_ru']}"
                puts "  Size:   	#{a['size']}"
                if a.has_key?("components")
                        puts "    Components:"
                        a["components"].each do |c|
                                puts "    ---"
                                puts "    #{c['name']}"
                                puts "    Serial: #{c['serial']}"
                                puts "    PO:     #{c['po']}"
                                puts "    DC:     #{a['dc']}"
                                puts "    Rack:   #{a['rack']}"
                                puts "    Top_RU: #{a['top_ru']}"
                                puts "    Bot_RU: #{a['bot_ru']}"
                                puts "    Size:   #{a['size']}"
                        end
                end
        end
end

#"MAIN"
assets=asset_load()

        #Need at least 2 argument to start
        if ARGV.length < 1
                puts "Please see #{$0} help for usage"
        else
                #we got at least A argument...
                major=ARGV[0]
                case major
                when "help"
                        #help
                        print_help_main()
                when "add"
                        #Okay, so, for this, we require some more options, but this will let us add in bulk in teh furture, along w/ import...
                        if (ARGV.length < 2) or (ARGV[1] == "help")
                                puts "Not enough info to add asset"
                                puts "Correct usage:"
                                puts "#{$0} add *<asset_name> <asset_serial> <asset_po> <datacenter> <rack> <top_ru> <bot_ru>"
                                puts ""
                                puts "* denotes required"
                        else
                                #we got the args, now build the asset
                                asset=new_asset(ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5],ARGV[6].to_i,ARGV[7].to_i)
                                if asset_duplicate_check(asset,assets)
                                        add_asset(asset, assets)
                                end
                        end
                when "list"
                        #no extra args needed, just print it all
                        sorted=sort_assets(assets)
                        print_assets(sorted)
                when "search"
                        #need a field to search on, and a search string
                        if ARGV.length != 3
                                puts "Not enough info to search on"
                                puts "Correct usage:"
                                puts "#{$0} search <feild> <search_string>"
                                puts "Where field is name,serial,po,dc,rack,top_ru,bot_ru,size"
                        else
                                results=find_asset(assets,ARGV[1],ARGV[2])
                                sorted=sort_assets(results)
                                print_assets(sorted)
                        end
                when "modify"
                        if ARGV.length != 4
                                puts "Not enough info, see \"#{$0} modify help\""
                        else
                        minor=ARGV[1]
                        case minor
                        when "help"
                                puts "Usage:"
                                puts "Modify Asset name:"
                                puts "  #{$0} modify <asset_name> <field to modify> <new value>"
                                puts "Where <field to modify> is \"name\", \"serial\", \"po\", \"dc\" ,\"rack\" \"top_ru\" or \"bot_ru\""
                        else
                                if ARGV.length == 4
                                        name=ARGV[1]
                                        field=ARGV[2]
                                        new=ARGV[3]
                                        #find the asset to change, we only modify by name so search on name
                                        results=find_asset(assets,"name",name)
                                        #make sure we only got 1
                                        if results.length == 1
                                                #okay, got one.
                                                asset=results[0]
                                                asset[field] = new
                                                asset=update_stamp(asset)
                                                if field == "top_ru"
                                                        size=size_calc(new.to_i,asset["bot_ru"])
                                                        asset["size"]=size
                                                        asset=update_stamp(asset)
                                                elsif field == "bot_ru"
                                                        size=size_calc(asset["top_ru"],new.to_i)
                                                        asset["size"]=size
                                                        asset=update_stamp(asset)
                                                end
                                        else
                                                puts "Whoa, I found multiple assets, freaking out(by that I mean quiting with no changes)"
                                                exit
                                        end
                                end
                        end
                end
                when "component"
                        if ARGV.length <= 1
                                puts "Not enough info, see \"#{$0} component help\""
                        else
                                minor=ARGV[1]
                                case minor
                                when "help"
                                        puts "Usage:"
                                        puts "#{$0} component <command> <options>"
                                        puts "Where <command> is one of:"
                                        puts "search:   search components on any field"
                                        puts "add:      add a component to an asset"
                                        puts "modify:   modify a component"
                                        puts "delete:   delete a component from an asset"
                                when "search"
                                        if ARGV.length !=4
                                                puts "Not enough info to search on"
                                                puts "Correct usage:"
                                                puts "#{$0} component search <feild> <search_string>"
                                                puts "Where field is name,serial,po,dc,rack,top_ru,bot_ru,size"
                                        else
                                                results=find_component(assets,ARGV[2],ARGV[3])
                                                if results != nil
                                                        sorted=sort_assets(results)
                                                        print_assets(sorted)
                                                end
                                        end
                                when "add"
                                        if ARGV.length < 4
                                                puts  "Not enough info to add a component"
                                                puts "Correct usage:"
                                                puts "#{$0} component add *<asset_nane> *<component_name> <component_serial> <component_po> <datacenter> <rack> <top_ru> <bot_ru>"
                                                puts ""
                                                puts "* denotes required"
                                        else
                                                #got args needed
                                                results=find_asset(assets,"name",ARGV[2])
                                                if results.length == 1
                                                        #okay, got one.
                                                        asset=results[0]
                                                        asset=add_comp(asset,ARGV[3],ARGV[4],ARGV[5],ARGV[6],ARGV[7],ARGV[8],ARGV[9])
                                                end
                                        end
                                when "modify"
                                        if ARGV.length !=6
                                                puts "Not enough info, please see \"#{$0} component modify help\" "
                                        else
                                                case ARGV[2]
                                                when "help"
                                                        puts "Usage:"
                                                        puts "#{$0} component <asset_name> <component_name> <component_field> <new_value>"
                                                else
                                                        #we got the args needed.
                                                        asset_name=ARGV[2]
                                                        comp_name=ARGV[3]
                                                        comp_field=ARGV[4]
                                                        comp_new=ARGV[5]
                                                        #find the asset
                                                        results=find_component(assets,"name",comp_name)
                                                        if results != nil
                                                                if results.length==1
                                                                        #found 1
                                                                        #get the component
                                                                        asset=results[0]
                                                                        comps=asset["components"]
                                                                        comps.each do |c|
                                                                                if c["name"] == comp_name
                                                                                        #found it
                                                                                        c[comp_field] = comp_new
                                                                                        asset=update_stamp(asset)
                                                                                end
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                when "delete"
                                        if ARGV.length !=4
                                                puts "Not enough info, please see \"#{$0} component delete help\""
                                        else
                                                case ARGV[2]
                                                when "help"
                                                        puts "Usage:"
                                                        puts "#{$0} component delete <asset_name> <component_name>"
                                                else
                                                        asset_name=ARGV[2]
                                                        comp_name=ARGV[3]
                                                        results=find_component(assets,"name",comp_name)
                                                        if results != nil
                                                                if results.length==1
                                                                        #found 1
                                                                        #get the component
                                                                        asset=results[0]
                                                                        comps=asset["components"]
                                                                        comps.each do |c|
                                                                                if c["name"] == comp_name
                                                                                        puts "Are you sure you want to delete the component #{comp_name} from #{asset_name}?"
                                                                                        puts "(y/n)"
                                                                                        ans=$stdin.gets.chomp
                                                                                        if ans.casecmp("y") == 0
                                                                                                comps.delete(c)
                                                                                        else
                                                                                                puts "Aborting delete"
                                                                                        end
                                                                                end
                                                                        end
                                                                        if comps.length == 0
                                                                                asset.delete("components")
                                                                        end
                                                                end
                                                        end

                                                end
                                        end
                                end

                        end
                when "delete"
                        #we get 1 more argument here, the name of the asset
                        if ARGV.length != 2
                                puts "Not enough info,  see \"#{$0} delete help\""
                        else
                        case ARGV[1]
                        when "help"
                                puts "Usage:"
                                puts "#{$0} delete <name>"
                                puts "Where <name> is the name of the asset to delete"
                        else
                                name=ARGV[1]
                                #find it, and display it
                                results=find_asset(assets,"name",name)
                                if results.length == 1
                                        asset = results[0]
                                        puts "Are you SURE you want to DELETE the asset:"
                                        print_assets(results)
                                        puts "(y/n)?"
                                        ans=$stdin.gets.chomp
                                        if ans.casecmp("y") == 0
                                                #really remove it
                                                assets.delete(asset)
                                        else
                                                puts "Aborting delete."
                                        end
                                else
                                end
                        end

                        end
                when "export"
                        if ARGV.length != 2
                                puts "Please specify an export format:"
                                puts "yaml: YAML export"
                                puts "json: JSON export"

                        else
                                format = ARGV[1]
                                if format == "yaml"
                                        puts assets.to_yaml
                                elsif format == "json"
                                        puts assets.to_json
                                else
                                        puts "Unknown format"
                                end
                        end
                when "import"
                        if ARGV.length < 3
                                puts "Please enter a filename (absolute or relative)"
                                puts "This MUST be a comma-separated list format"
                                puts "You may specify the feilds as such:"
                                puts ""
                                puts "#{$0} import <file_path> feild1,feild2,feild3"
                                puts "Example:"
                                puts "#{$0} import data.csv name,serial,po"
                        else
                                file=ARGV[1]
                                fields=ARGV[2].split(",")
                                puts "Importing from #{file}"
                                puts "Using the feilds:"
                                fields.each do |f|
                                        puts f
                                end
                                import = Array.new
                                if File.exists?(file)
                                        f=File.open(file,'r')
                                        f.each do |line|
                                                element=line.split(',')
                                                if element.length == fields.length
                                                        #they MUST match
                                                        asset=Hash.new
                                                        i=0
                                                        until i >= element.length
                                                                asset[fields[i]] = element[i].chomp
                                                                i+=1
                                                        end
                                                import.push(asset)
                                                end
                                        end
                                end
                                pp import
                                puts "Does this look okay?"
                                puts "(y/n)?"
                                ans=$stdin.gets.chomp
                                if ans.casecmp("y") == 0
                                        #assets = assets|import
                                        #add them via the add function
                                        import.each do |i|
                                                asset=new_asset(i["name"],i["serial"],i["po"],i["dc"],i["rack"],i["top_ru"],i["bot_ru"])
                                                if asset_duplicate_check(asset,assets)
                                                     add_asset(asset, assets)
                                                end
                                        end
                                end
                        end

                else
                        print_help_main()
                end
        end

asset_save(assets)
