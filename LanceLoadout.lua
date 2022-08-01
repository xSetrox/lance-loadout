util.require_natives("1640181023")

store_dir = filesystem.store_dir() .. '\\lance_loadout\\'

if not filesystem.is_dir(store_dir) then
    filesystem.mkdirs(store_dir)
end

-- UTILITY FUNCTIONS
-- FROM http://lua-users.org/wiki/SaveTableToFile

local function exportstring( s )
    return string.format("%q", s)
end

function table.save(  tbl,filename )
   local charS,charE = "   ","\n"
   local file,err = io.open( filename, "wb" )
   if err then return err end
   -- initiate variables for save procedure
   local tables,lookup = { tbl },{ [tbl] = 1 }
   file:write( "return {"..charE )
   for idx,t in ipairs( tables ) do
      file:write( "-- Table: {"..idx.."}"..charE )
      file:write( "{"..charE )
      local thandled = {}
      for i,v in ipairs( t ) do
         thandled[i] = true
         local stype = type( v )
         -- only handle value
         if stype == "table" then
            if not lookup[v] then
               table.insert( tables, v )
               lookup[v] = #tables
            end
            file:write( charS.."{"..lookup[v].."},"..charE )
         elseif stype == "string" then
            file:write(  charS..exportstring( v )..","..charE )
         elseif stype == "number" then
            file:write(  charS..tostring( v )..","..charE )
         end
      end
      for i,v in pairs( t ) do
         -- escape handled values
         if (not thandled[i]) then
            local str = ""
            local stype = type( i )
            -- handle index
            if stype == "table" then
               if not lookup[i] then
                  table.insert( tables,i )
                  lookup[i] = #tables
               end
               str = charS.."[{"..lookup[i].."}]="
            elseif stype == "string" then
               str = charS.."["..exportstring( i ).."]="
            elseif stype == "number" then
               str = charS.."["..tostring( i ).."]="
            end
            if str ~= "" then
               stype = type( v )
               -- handle value
               if stype == "table" then
                  if not lookup[v] then
                     table.insert( tables,v )
                     lookup[v] = #tables
                  end
                  file:write( str.."{"..lookup[v].."},"..charE )
               elseif stype == "string" then
                  file:write( str..exportstring( v )..","..charE )
               elseif stype == "number" then
                  file:write( str..tostring( v )..","..charE )
               end
            end
         end
      end
      file:write( "},"..charE )
   end
   file:write( "}" )
   file:close()
end

function table.load( sfile )
   local ftables,err = loadfile( sfile )
   if err then return _,err end
   local tables = ftables()
   for idx = 1,#tables do
      local tolinki = {}
      for i,v in pairs( tables[idx] ) do
         if type( v ) == "table" then
            tables[idx][i] = tables[v[1]]
         end
         if type( i ) == "table" and tables[i[1]] then
            table.insert( tolinki,{ i,tables[i[1]] } )
         end
      end
      -- link indices
      for _,v in ipairs( tolinki ) do
         tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
      end
   end
   return tables[1]
end
-- END UTILITY FUNCTIONS

--https://gist.github.com/xSetrox/20faaea29d48369ffd814460a8908d44/raw
comp_path = store_dir .. '\\all_components.txt'
liveries_path = store_dir .. '\\all_liveries.txt'
need_install_components = false
need_install_liveries = false
if not filesystem.exists(comp_path) then
    need_install_components = true
    async_http.init('gist.githubusercontent.com', '/xSetrox/0e75d50b366a32503a0f431abd6525c2/raw', function(data)
        local file = io.open(comp_path,'w')
        file:write(data)
        file:close()
        need_install_components = false
    end)
    async_http.dispatch()
end

if not filesystem.exists(liveries_path) then
    need_install_liveries = true
    async_http.init('gist.githubusercontent.com', '/xSetrox/20faaea29d48369ffd814460a8908d44/raw', function(data)
        local file = io.open(liveries_path,'w')
        file:write(data)
        file:close()
        need_install_liveries = false
    end)
    async_http.dispatch()
end

while need_install_components or need_install_liveries do
    util.yield()
end

local all_components = {}
local all_liveries = {}

for line in io.lines(comp_path) do 
    all_components[#all_components+1] = tonumber(line)
end

for line in io.lines(liveries_path) do 
    all_liveries[#all_liveries+1] = tonumber(line)
end

-- credit http://lua-users.org/wiki/StringRecipes
local function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
 end


local all_loadouts = {}
function update_all_loadouts()
    temp_loadouts = {}
    for i, path in ipairs(filesystem.list_files(store_dir)) do
        local file_str = path:gsub(store_dir, '')
        if ends_with(file_str, '.loadout') then
            temp_loadouts[#temp_loadouts+1] = file_str
        end
    end
    all_loadouts = temp_loadouts
end
update_all_loadouts()

weapons = {}
temp_weapons = util.get_weapons()
-- create a table with just weapon hashes, labels
for a,b in pairs(temp_weapons) do
    weapons[#weapons + 1] = {hash = b['hash'], label_key = b['label_key']}
end

function weapon_name_from_hash(hash)
    for k,v in pairs(weapons) do
        if tostring(v['hash']) == tostring(hash) then
            return util.get_label_text(v['label_key'])
        end
    end
    return nil
end

function format_weapon_name_for_stand(name)
    local name_copy = string.lower(name)
    local forbidden_chars = {'%_', '%.', '%-', ' '}
    for k,char in pairs(forbidden_chars) do 
        name_copy = string.gsub(name_copy, char, '')
    end
    if name_copy == 'stungun' then
        name_copy = 'stungunsp'
    end
    return name_copy
end

function get_weapons_ped_has(ped)
    local p_weapons = {}
    for k,v in pairs(weapons) do
        if WEAPON.HAS_PED_GOT_WEAPON(ped, v.hash, false) then 
            local this_weapon = {
                weapon = v.hash,
                tint = -1,
                components = {},
                liveries = {}
            }
            for k,comp in pairs(all_components) do
                if WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(v.hash, comp) then
                    if WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(players.user_ped(), v.hash, comp) then
                        this_weapon.components[#this_weapon.components+1] = comp
                    end
                end
            end
            this_weapon.tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(players.user_ped(), v.hash)
            for k,livery in pairs(all_liveries) do
                local livery_color = WEAPON._GET_PED_WEAPON_LIVERY_COLOR(players.user_ped(), v.hash, livery)
                if livery_color ~= -1 then 
                    this_weapon.liveries[#this_weapon.liveries+1] = {livery = livery, color = livery_color}
                end
            end
            p_weapons[#p_weapons+1] = this_weapon
        end
    end
    return p_weapons
end

local load_list_actions
menu.action(menu.my_root(), "Save loadout", {"saveloadout"}, "Save your character\'s current loadout", function()
    util.toast("Please input the name of this loadout")
    menu.show_command_box("saveloadout ")
end, function(file_name)
    local weps = get_weapons_ped_has(players.user_ped())
    table.save(weps, store_dir .. file_name .. '.loadout')
    util.toast("Loadout saved as " .. file_name .. ".loadout")
    update_all_loadouts()
    menu.set_list_action_options(load_list_actions, all_loadouts)
end)

load_list_actions = menu.list_action(menu.my_root(), "Load loadout", {"loadloadout"}, "Load a loadout from file", all_loadouts, function(index, value, click_type)
    util.toast("Loading loadout...")
    menu.trigger_commands('noguns')
    local error_ct = 0
    local success_ct = 0
    local wep_tbl = table.load(store_dir .. '/' .. value)
    for k,wep in pairs(wep_tbl) do
        menu.trigger_commands('getguns' .. format_weapon_name_for_stand(weapon_name_from_hash(wep.weapon)))
        for k, l in pairs(wep.liveries) do 
            WEAPON._SET_PED_WEAPON_LIVERY_COLOR(players.user_ped(), wep.weapon, l.livery, l.color)
        end
        for k, c in pairs(wep.components) do
            WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(players.user_ped(), wep.weapon, c)
        end
    end
    --util.toast("Loadout " .. value .. " loaded. " .. success_ct .. " guns loaded successfully, " .. error_ct .. " errors.")
end)

-- update all loadouts every 5 seconds so if a user drags in a loadout it shows up :)
util.create_thread(function()
    while true do
        update_all_loadouts()
        menu.set_list_action_options(load_list_actions, all_loadouts)
        util.yield(5000)
    end
end)



menu.action(menu.my_root(), "Clear loadout", {"clearloadout"}, "Clear your current loadout", function()
    menu.trigger_commands('noguns')
end)


util.keep_running()
