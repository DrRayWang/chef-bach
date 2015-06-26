require 'json'

module PreChef
  class NodeSearch
    
    def initialize(rolefilepath,clusterfilepath)
      @rolefilepath = rolefilepath
      @clusterfilepath = clusterfilepath
      @roleFiles = Dir["#{rolefilepath}/*.json"]
    end
    
    def getRoleForThing(thing,filename)
      basename = File.basename(filename)
      roleFile = File.read(filename)
      parsed_json = JSON.parse(roleFile)
      runlist = parsed_json["run_list"]
      if runlist != nil
        runlist.each do |item|
          #puts "#{item},#{thing}"
          if item.include?(thing)
            return basename[0,basename.index('.')]
          end
        end
      end
      return nil
    end
    
    def getRoleList(thing)
      roleList = Array.new
      @roleFiles.each do |f|
        role = getRoleForThing(thing,f)
        if role != nil
          roleList << role
        end
      end
      return roleList
    end
    
    
    
    def getFullRoles(thing)
      roles = Array.new
      queue = getRoleList(thing)
      roles = roles + queue
      while queue.size != 0 do
        item = queue.pop
        inroles = getRoleList(item)
        inroles.each do |role|
          if ! roles.include?(role)
            queue << role
            roles << role
          end
        end
      end
      roles
    end
      
    def getClusterRoleInfo
      roleDic = Hash.new
      f = File.open(@clusterfilepath)
      f.each do |line|
        if line == nil || line == ""
          next
        end
        items = line.split(" ")
        roles = items[items.size-1].gsub!("role",'').gsub!("[",'').gsub!("]",'')
        roleDic[items[0]] = roles.split(",")
      end
      f.close
      return roleDic
    end
    
    def getNodeList(noderoles,rolelist)
      nodeList = Array.new
      noderoles.each do |node,roles|
        roles.each do |role|
          if rolelist.include?(role)
            nodeList << node
            break
          end  
        end  
      end
      nodeList  
    end
    
    def nodeSearch(thing)
      roleList = getFullRoles("#{thing}]")
      roleDic = getClusterRoleInfo
      result = getNodeList(roleDic,roleList)
      result
    end
    
    def getInvolvedRecipes(thing, cookbookspath)
      recipes = `grep -l "include_recipe.*#{thing}'" -r #{cookbookspath}`
      recipes.split("\n").each do |name|
        recipeList << File.basename(name)
      end
      end
  end
end

#search = NodeSearch.new("/Users/rwang238/Projects/chef-bach/roles", "/Users/rwang238/Projects/chef-bach/cluster.txt")
#nodelist = search.nodeSearch("oozie_config")
# make it failed when when we don't want it has access
# need exception handler here
#puts nodelist
#recipes = search.recipeRecursiveSearch("oozie_config","/Users/rwang238/Projects/chef-bach/")
