#!/usr/bin/lua

require "uci"
require "ubus"
require "uloop"

function getConfType(conf,type)
  local curs=uci.cursor()
  local ifce={}
  curs:foreach(conf,type,function(s) ifce[s[".index"]]=s end)
  return ifce
end

local uci_cursor = uci.cursor()
local host = uci_cursor:get("dynapoint", "internet", "host")

if (tonumber(uci_cursor:get("dynapoint", "internet", "add_hostname_to_ssid")) == 1 ) then
  localhostname = uci_cursor:get("system", "system", "hostname")
end

print(localhostname)
local host2 = "http://www.google.com"
local interval = uci_cursor:get("dynapoint", "internet", "interval")
local timeout = uci_cursor:get("dynapoint", "internet", "timeout")
local offline_threshold = tonumber(uci_cursor:get("dynapoint", "internet", "offline_threshold"))

function get_dynapoint(t)
  for pos,val in pairs(t) do
    if (type(val)=="table") then
      get_dynapoint(val);
    elseif (type(val)=="string") then
      if (pos == "dynapoint") then
        if (val == "1") then
          table_name_1=t[".name"]
          print(table_name_1)
        elseif (val == "0") then
          table_name_0=t[".name"]
          print(table_name_0)
        end
      end
    end
  end
end

function print_r ( t )
  local print_r_cache={}
  local function sub_print_r(t,indent)
    if (print_r_cache[tostring(t)]) then
      print(indent.."*"..tostring(t))
    else
      print_r_cache[tostring(t)]=true
      if (type(t)=="table") then
        for pos,val in pairs(t) do
          if (type(val)=="table") then
            print(indent.."["..pos.."] => "..tostring(t).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            print(indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            print(indent.."["..pos..'] => "'..val..'"')
          else
            print(indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        print(indent..tostring(t))
      end
    end
  end
  if (type(t)=="table") then
    print(tostring(t).." {")
    sub_print_r(t,"  ")
    print("}")
  else
    sub_print_r(t,"  ")
  end
  print()
end

print_r(getConfType("wireless", "wifi-iface"))


get_dynapoint(getConfType("wireless","wifi-iface"))

uloop.init()

conn = ubus.connect()
if not conn then
  error("Failed to connect to ubusd")
end

local online = true
local timer
local offline_counter = 0

function do_internet_check(host)
  local result = os.execute("wget -q --timeout="..timeout.." --spider "..host)
  if (result == 0) then
    return true
  else
    return false
  end
end

function check_internet_connection()
  print("checking connection")
  if (do_internet_check(host) == true) then
    -- online
    offline_counter = 0
    if (online == false) then
      print("changed to online")
      online = true
      uci_cursor = uci.cursor()
      uci_cursor:set("wireless", table_name_0 , "disabled", "1")
      uci_cursor:set("wireless", table_name_1 , "disabled", "0")
      if (localhostname) then
        uci_cursor:set("wireless", table_name_0, "ssid", ssid)
      end

      uci_cursor:commit("wireless")
      conn:call("network", "reload", {})
    end
  else
    --offline
    if (do_internet_check(host2) == false) then
      offline_counter = offline_counter + 1
      if (offline_counter == offline_threshold) then
        print("changed to offline")
        online = false
        uci_cursor = uci.cursor()
        if (localhostname) then
          ssid = uci_cursor:get("wireless", table_name_0, "ssid")
          print(ssid)
          ssid2 = ssid.."_"..localhostname
          print(ssid2)
          uci_cursor:set("wireless", table_name_0, "ssid", ssid2)
        end
        uci_cursor:set("wireless", table_name_0, "disabled", "0")
        uci_cursor:set("wireless", table_name_1, "disabled", "1")
        uci_cursor:commit("wireless")
        conn:call("network", "reload", {})
      end
    end
  end
  timer:set(interval * 1000)
end

timer = uloop.timer(check_internet_connection)
timer:set(interval * 1000)


--local my_method = {
--  dynapoint = {
--    online = {
--      function(req, msg)
--        conn:reply(req, {status="online",interface=msg.interface});
--        print("Call to function 'online'")
--        print("Interface=" .. msg.interface)
--
--        uci_cursor = uci.cursor()
--        uci_cursor:set("wireless", table_name_0 , "disabled", "1")
--        uci_cursor:set("wireless", table_name_1 , "disabled", "0")
--        conn:call("network", "reload", {})
--
--      end, {interface = ubus.STRING }
--    },
--    offline = {
--      function(req, msg)
--        conn:reply(req, {status="offline",interface=msg.interface});
--        print("Call to function 'offline'")
--        print("Interface=" .. msg.interface)
--        uci_cursor = uci.cursor()
--        uci_cursor:set("wireless", table_name_0, "disabled", "0")
--        uci_cursor:set("wireless", table_name_1, "disabled", "1")
--        conn:call("network", "reload", {})
--      end, {interface = ubus.STRING }
--    }
--  }
--}

--conn:add(my_method)

uloop.run()
