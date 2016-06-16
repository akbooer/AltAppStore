module ("L_AltAppStore", package.seeall)

-- // This program is free software: you can redistribute it and/or modify
-- // it under the condition that it is for private or home useage and 
-- // this whole comment is reproduced in the source code file.
-- // Commercial utilisation is not authorized without the appropriate written agreement.
-- // This program is distributed in the hope that it will be useful,
-- // but WITHOUT ANY WARRANTY; without even the implied warranty of
-- // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE . 

local ABOUT = {
  NAME          = "AltAppStore",
  VERSION       = "2016.06.16",
  DESCRIPTION   = "update plugins from Alternative App Store",
  AUTHOR        = "@akbooer / @amg0 / @vosmont",
  COPYRIGHT     = "(c) 2013-2016",
  DOCUMENTATION = "https://github.com/akbooer/AltAppStore",
}

-- Plugin for Vera
--
-- a collaborative effort:
--   Web:      @vosmont
--   (Alt)UI:  @amg0
--   Plugin:   @akbooer
--

local https     = require "ssl.https"
local lfs       = require "lfs"

local json      = require "L_ALTUIjson"   -- we will always run with AltUI present

https.TIMEOUT = 5

local devNo     -- our own device number

local SID = {
  altui = "urn:upnp-org:serviceId:altui1",                -- Variables = 'DisplayLine1' and 'DisplayLine2'
  apps  = "urn:upnp-org:serviceId:AltAppStore1",
  hag   = "urn:micasaverde-com:serviceId:HomeAutomationGateway1",
}

local icon_directories = {
  [true] = "icons/",                                            -- openLuup icons
  [5] = "/www/cmh/skins/default/icons/",                        -- UI5 icons
  [6] = nil,                                                    -- TODO: discover where UI6 icons go
  [7] = "/www/cmh/skins/default/img/devices/device_states/",    -- UI7 icons
}

local ludl_directories = {
  [true] = "./",                -- openLuup (since default dir may not be /etc/cmh-ludl/)
  [5] = "/etc/cmh-ludl/",       -- UI5 
  [7] = "/etc/cmh-ludl/",       -- UI7
}

local icon_folder = icon_directories[(luup.version_minor == 0 ) or luup.version_major]
local ludl_folder = ludl_directories[(luup.version_minor == 0 ) or luup.version_major]

local _log = function (...) luup.log (table.concat ({ABOUT.NAME, ':', ...}, ' ')) end

local pathSeparator = '/'

-- utilities

local function setVar (name, value, service, device)
  service = service or SID.apps
  device = device or devNo
  local old = luup.variable_get (service, name, device)
  if tostring(value) ~= old then 
   luup.variable_set (service, name, value, device)
  end
end

local function display (line1, line2)
  if line1 then luup.variable_set (SID.altui, "DisplayLine1",  line1 or '', devNo) end
  if line2 then luup.variable_set (SID.altui, "DisplayLine2",  line2 or '', devNo) end
end

-- UI7 return status : {0 = OK, 1 = Device config error, 2 = Authorization error}
local function set_failure (status)
  if (luup.version_major < 7) then status = status ~= 0 end        -- fix UI5 status type
  luup.set_failure(status)
end

-- UI5 doesn't have the luup.create_device function!

local function UI5_create_device (device_type, altid, name, device_file, 
      device_impl, ip, mac, hidden, invisible, parent, room, pluginnum, statevariables)  
  local _ = {hidden, invisible}   -- unused
  -- do appreciate the following naming inconsistencies which Luup enjoys... 
  local args = {
    deviceType = device_type,
    internalID = altid,
    Description = name,
    UpnpDevFilename = device_file,
    UpnpImplFilename = device_impl,
    IpAddress = ip,
    MacAddress = mac,
--Username 	string
--Password 	string
    DeviceNumParent = parent,
    RoomNum = room,
    PluginNum = pluginnum,
    StateVariables = statevariables,
--Reload 	boolean  If Reload is 1, the Luup engine will be restarted after the device is created. 
  }
  local err, msg, job, arg = luup.call_action (SID.hag, "CreateDevice", args, 0)
  return err, msg, job, arg
end

-------------------------------------------------------
--
-- update plugins from GitHub repository
--

local _ = {
  NAME          = "openLuup.github",
  VERSION       = "2016.06.16",
  DESCRIPTION   = "download files from GitHub repository",
  AUTHOR        = "@akbooer",
  COPYRIGHT     = "(c) 2013-2016 AKBooer",
  DOCUMENTATION = "https://github.com/akbooer/openLuup/tree/master/Documentation",
}

-- 2016.03.15  created
-- 2016.04.25  make generic, for use with openLuup / AltUI / anything else
-- 2016.06.16  just return file contents using iterator, don't actually write any files.

-------------------------
--
--  GitHub() - factory function for individual plugin update from GitHub
--
--  parameter:
--    archive = "akbooer/openLuup",           -- GitHub repository
--

function GitHub (archive)     -- global for access by other modules

  -- get and decode GitHub url
  local function git_request (request)
    local decoded, errmsg
    local response = https.request (request)
    if response then 
      decoded, errmsg = json.decode (response)
    else
      errmsg = response
    end
    return decoded, errmsg
  end
  
  -- return a table of tagged releases, indexed by name, 
  -- with GitHub structure including commit info
  local function get_tags ()
    local tags
    local Ftag_request  = "https://api.github.com/repos/%s/tags"
    local resp, errmsg = git_request (Ftag_request: format (archive))
    if resp then 
      tags = {} 
      for _, x in ipairs (resp) do
        tags[x.name] = x
      end
    end
    return tags, errmsg
  end
  
  -- find the tag of the newest released version
  local function latest_version ()
    local tags = {}
    local t, errmsg = get_tags ()
    if not t then return nil, errmsg end
    for v in pairs (t) do tags[#tags+1] = v end
    table.sort (tags)
    local latest = tags[#tags]
    return latest
  end
  
  
  -- get specific parts of tagged release
  local function get_release_by_file (v, subdirectories, pattern)
    local files, N = {}, 0
    local resp, errmsg
    
    -- iterator for each file we want
    -- returns code, name, content
    local function get_next_file ()
      N = N+1
      local x = files[N]
      if not x then return end            -- used at end of iteration (no more files)
      local content, code = https.request(x.download_url)
      return code, x.name, content, N, #files   -- code = 200 is success
    end
    
    for _, d in ipairs (subdirectories) do
      local Fcontents = "https://api.github.com/repos/%s/contents"
      local request = table.concat {Fcontents: format (archive),d , "?ref=", v}
      resp, errmsg = git_request (request)
      if resp then
  
        for _, x in ipairs (resp) do     -- x is a GitHub descriptor with name, path, etc...
          local wanted = (x.type == "file") and (x.name):match (pattern or '.') 
          if wanted then files[#files+1] = x end
        end
      
      else
        return nil, errmsg or "unknown error" 
      end
    end
    
    return get_next_file
  end
  
  -- GitHub()
  return {
    get_tags = get_tags,
    get_release_by_file = get_release_by_file,
    latest_version = latest_version,
  }
end

 
-------------------------------------------------------

local _ = {
  NAME          = "openLuup.plugins",
  VERSION       = "2016.06.16",
  DESCRIPTION   = "create/delete plugins",
  AUTHOR        = "@akbooer",
  COPYRIGHT     = "(c) 2013-2016 AKBooer",
  DOCUMENTATION = "https://github.com/akbooer/openLuup/tree/master/Documentation",
}

-- utilities


-- return first found device ID if a device of the given type is present locally
local function present (device_type)
  for devNo, d in pairs (luup.devices) do
    if (d.device_num_parent == 0)     -- local device!!
    and (d.device_type == device_type) then
      return devNo
    end
  end
end

-- check to see if plugin needs to install device(s)
-- at the moment, only create the FIRST device in the list
-- (multiple devices are a bit of a challenge to identify uniquely)
local function install_if_missing (plugin, name)
  local devices = plugin["Devices"] or plugin["devices"] or {}
  local device1 = devices[1] or {}
  local device_type = device1["DeviceType"]
  local device_file = device1["DeviceFileName"]
  local device_impl = device1["ImplFile"]
  local statevariables = device1["StateVariables"]
  local pluginnum = plugin.id
  name = name or '?'
  
  local function install (plugin)
    local ip, mac, hidden, invisible, parent, room
    local altid = ''
    _log ("installing " .. name)
    -- device file comes from Devices structure
    local devNo = (luup.create_device or UI5_create_device) (device_type, altid, name, device_file, 
      device_impl, ip, mac, hidden, invisible, parent, room, pluginnum, statevariables)  
    return devNo
  end
  
  local devNo
  if device_type and not present (device_type) then 
    devNo = install(plugin) 
  end
  return devNo
end

local function file_copy (source, destination)
  local f = io.open (source, "rb")
  if f then
    local content = f: read "*a"
    f: close ()
    local g = io.open (destination, "wb")
    if g then
      g: write (content)
      g: close ()
    else
      _log ("error writing", destination)
    end
  end
end

-------------------------------------------------------
--
-- AltAppStore's own metadata structure:
--

local AltAppStore =  
  {
    AllowMultiple   = "0",
    Title           = "AltAppStore",
    Icon            = "https://raw.githubusercontent.com/akbooer/AltAppStore/master/AltAppStore.png", 
    Instructions    = "https://github.com/akbooer/AltAppStore",  --TODO: change to better documentation
    AutoUpdate      = "0",
    VersionMajor    = "not",
    VersionMinor    = "installed",
    id              = "AltAppStore",    -- TODO: replace with real id once in MiOS App Store?
--    timestamp       = os.time(),
    Files           = {},
    Devices         = {
      {
        DeviceFileName  = "D_AltAppStore.xml",
        DeviceType      = "urn:schemas-upnp-org:device:AltAppStore:1",
        ImplFile        = "I_AltAppStore.xml",
        Invisible       =  "0",
--        CategoryNum = "1",
--        StateVariables = "..." -- see luup.create_device documentation
      },
    },
    Repository      = {
      {
        type      = "GitHub",
        source    = "akbooer/AltAppStore",
  --      folders = {                     -- these are the bits we need
  --        "subdir1",
  --        "subdir2",
  --      },
  --      pattern = "[DIJLS]_%w+%.%w+"     -- Lua pattern string to describe wanted files
        pattern   = "AltAppStore",                   -- pattern match string for required files
      },
    }
  }


-------------------------------------------------------
--
-- the update_plugin action is implemented in two parts:
-- <run>  validity checks, etc.
-- <job>  phased download, with control returned to scheduler between individual files
--

-- these variables are shared between the two phases...
local ipl         -- the plugin metadata
local next_file   -- download iterator
local target      -- location for downloads
local total       -- total file transfer size
local plugin_name

function update_plugin_run(p)
  _log "starting <run> phase..."
  p.metadata = p.metadata or json.encode (AltAppStore)     -- TESTING ONLY!
  ipl = json.decode (p.metadata)
  
  if type (ipl) ~= "table" then 
    _log "invalid metadata: JSON table decode error"
    return false                            -- failure
  end
  
  local r = ipl.repository
  local v = ipl.versionid
  
  if not (r and v) then 
    _log "invalid metadata: missing repository or versionid"
    return false
  end
  
  local t = r.type
  local w = (r.versions or {}) [v] or {}
  local rev = w.release
  if not (t == "GitHub" and type(rev) == "string") then
    _log "invalid metadata: missing GitHub release"
    return false
  end
  
  target = table.concat ({'', "tmp", "AltAppStore",''}, pathSeparator)
  lfs.mkdir (target)
  local updater = GitHub (r.source)
    
  _log ("downloading", r.source, '['..rev..']', "to", target) 
  local folders = r.folders or {''}    -- these are the bits of the repository that we want
  local info
  next_file, info = updater.get_release_by_file (rev, folders, r.pattern) 
  
  if not next_file then
    _log ("error downloading:", info)
    return false
  end
  
  _log ("getting contents of version:", rev)
  
  plugin_name = r.source: match "/(.+)$" or r.source
  display ("Downloading...", plugin_name)
  total = 0
  _log "starting <job> phase..."
  return true                               -- continue with <job>
end

-- these are the standard job return states
local jobstate =  {
    NoJob=-1,
    WaitingToStart=0,         -- If you return this value, 'job' runs again in 'timeout' seconds 
    InProgress=1,
    Error=2,
    Aborted=3,
    Done=4,
    WaitingForCallback=5,     -- This means the job is running and you're waiting for return data
    Requeue=6,
    InProgressPendingData=7,
 }

function update_plugin_job()
  
  local status, name, content, N, Nfiles = next_file()
  if status then
    if status ~= 200 then
      _log ("download failed, status:", status)
      --tidy up
      return jobstate.Error,0
    end
    local f, err = io.open (target .. name, "wb")
    if not f then 
      _log ("failed writing", name, "with error", err)
      return jobstate.Error,0
    end
    f: write (content)
    f: close ()
    local size = #content or 0
    total = total + size
    local column = "(%d of %d) %6d %s"
    _log (column:format (N, Nfiles, size, name))
    return jobstate.WaitingToStart,0        -- reschedule immediately
  else
    -- finish up
    _log ("Total size", total)
 
    -- copy files to final destination... 
    _log ("updating icons in", icon_folder, "...")
    _log ("updating device files in", ludl_folder, "...")
    for file in lfs.dir (target) do
      local source = target .. file
      local attributes = lfs.attributes (source)
      if file: match "^[^%.]" and attributes.mode == "file" then
        local destination
        if file:match ".+%.png$" then    -- ie. *.png
          destination = icon_folder .. file
        else
          destination = ludl_folder .. file
          local compressed_file = destination .. ".lzo"
          if lfs.attributes (compressed_file) then   
            os.remove (compressed_file)    -- remove existing compressed file
          end
        end
        file_copy (source, destination)
        os.remove (source)
      end
    end
       
    _log (plugin_name, "update completed")
    
    install_if_missing (ipl, plugin_name)
    display ('Reload','required')
    return jobstate.Done,0        -- finished job
  end
end


-------------------------------------------------------
--
-- Alt App Store
--

-- plugin initialisation
function init (d)
  devNo = d
  
  _log "starting..."
  display (ABOUT.NAME,'')
  
  setVar ("Version", ABOUT.VERSION)
  set_failure (0)
  return true, "OK", ABOUT.NAME
end
 
-----

