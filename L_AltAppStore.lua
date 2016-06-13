local ABOUT = {
  NAME          = "AltAppStore",
  VERSION       = "2016.06.12",
  DESCRIPTION   = "update plugins from Alternative App Store",
  AUTHOR        = "@akbooer / @amg0 / @vosmont",
  COPYRIGHT     = "(c) 2013-2016",
  DOCUMENTATION = "???",
}

-- Plugin for Vera
--
-- a collaborative effort:
--   Web:      @vosmont
--   (Alt)UI:  @amg0
--   Plugin:   @akbooer
--

local https     = require "ssl.https"
local ltn12     = require "ltn12"
local lfs       = require "lfs"

local json      = require "L_ALTUIjson"   -- we will always run with AltUI present

https.TIMEOUT = 5

local devNo     -- our own device number

local SID = {
  altui = "urn:upnp-org:serviceId:altui1",                -- Variables = 'DisplayLine1' and 'DisplayLine2'
  apps  = "urn:schemas-upnp-org:serviceId:AltAppStore1",
  hag   = "urn:micasaverde-com:serviceId:HomeAutomationGateway1",
}

local icon_directories = {
  [true] = "icons/",                                            -- openLuup icons
  [5] = "/www/cmh/skins/default/icons/",                        -- UI5 icons
  [6] = nil,                                                    -- TODO: discover where UI6 icons go
  [7] = "/www/cmh/skins/default/img/devices/device_states/",    -- UI7 icons
}

local ludl_directories = {
  [true] = "./",                -- openLuup (since default dir may not be named so)
  [5] = "/etc/cmh-ludl/",       -- UI5 
  [7] = "/etc/cmh-ludl/",       -- UI7
}

local icon_folder = icon_directories[(luup.version_minor == 0 ) or luup.version_major]
local ludl_folder = ludl_directories[(luup.version_minor == 0 ) or luup.version_major]

local _log = function (...) luup.log (table.concat ({ABOUT.NAME, ':', ...}, ' ')) end

local pathSeparator = '/'

-- utilities

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
  VERSION       = "2016.05.30",
  DESCRIPTION   = "update plugins from GitHub repository",
  AUTHOR        = "@akbooer",
  COPYRIGHT     = "(c) 2013-2016 AKBooer",
  DOCUMENTATION = "https://github.com/akbooer/openLuup/tree/master/Documentation",
}

-- note that these routines only update the files in the plugins/downloads directory,
-- they don't copy them to the /etc/cmh-ludl/ directory.

-- 2016.03.15  created
-- 2016.04.25  make generic, for use with openLuup / AltUI / anything else


-- utilities

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

-------------------------
--
--  GitHub() - factory function for individual plugin update from GitHub
--
--  parameters:
--    archive = "akbooer/openLuup",           -- GitHub repository
--    target  = "plugins/downloads/openLuup"  -- target directory for files and subdirectories
--

local function GitHub (archive, target) 
  
  -- ensure the download directories exist!
  local function directory_check (subdirectories)
    local function pathcheck (fullpath)
      local _,msg = lfs.mkdir (fullpath)
      _log (table.concat ({"checking directory", fullpath, ':', msg or "File created"}, ' '))
    end
    -- check or create path to the target root directory
    local path = {}
    for dir in target:gmatch "(%w+)" do
      path[#path+1] = dir
      pathcheck (table.concat(path, pathSeparator))
    end
    -- check or create subdirectories
    for _,subdir in ipairs (subdirectories) do
      pathcheck (target .. subdir)
    end
  end

  -- return a table of tagged releases, indexed by name, 
  -- with GitHub structure including commit info
  local function get_tags ()
    _log "getting release versions from GitHub..."
    local tags
    local Ftag_request  = "https://api.github.com/repos/%s/tags"
    local resp, errmsg = git_request (Ftag_request: format (archive))
    if resp then 
      tags = {} 
      for _, x in ipairs (resp) do
        tags[x.name] = x
      end
    else
      _log (errmsg)
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
    _log (table.concat (tags, ', '))
    local latest = tags[#tags]
    return latest
  end
  
  -- get file given a GitHub file descriptor
  local function get_file (x)
    if not x then return end            -- used at end of iteration (no more files)
    local fname = table.concat {target, x.name} 
    local _, code, headers = https.request{
        url = x.download_url,
        sink = ltn12.sink.file(io.open(fname, "wb+"))
      }
    local content_length = headers and headers["content-length"] or 0 
    return code, x.name, content_length   -- code = 200 is success
  end
  
  -- get specific parts of tagged release
  local function get_release_by_file (v, subdirectories, pattern)
    local ok = true
    local files, N = {}, 0
--    directory_check (subdirectories)
    directory_check {''}          -- just the main directory
    _log ("getting contents of version: " .. v)
    
    for _, d in ipairs (subdirectories) do
      _log ("...getting subdirectory: " .. d)
      local Fcontents = "https://api.github.com/repos/%s/contents"
      local request = table.concat {Fcontents: format (archive),d , "?ref=", v}
      local resp, errmsg = git_request (request)
      if resp then
        for _, x in ipairs (resp) do     -- x is a GitHub descriptor with name, path, etc...
          local wanted = (x.type == "file") and (x.name):match (pattern or '.') 
          if wanted then files[#files+1] = x end
        end
      else
        ok = false
        _log (errmsg)
      end
    end
    
    return function () N = N+1; return get_file (files[N]) end    -- iterator for each file we want
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
  VERSION       = "2016.06.08",
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
local function install_if_missing (plugin)
  local devices = plugin["Devices"] or {}
  local device1 = devices[1] or {}
  local device_type = device1["DeviceType"]
  local device_file = device1["DeviceFileName"]
  local device_impl = device1["ImplFile"]
  local statevariables = device1["StateVariables"]
  local pluginnum = plugin.id
  
  local function install (plugin)
    local ip, mac, hidden, invisible, parent, room
    local name = plugin.Title or '?'
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


-------------------------------------------------------
--
-- use IPhoneLocator as test example
--

local IPhone =  
  {
    AllowMultiple   = "1",
    Title           = "IPhoneLocator",
    Icon            = "https://raw.githubusercontent.com/amg0/IPhoneLocator/master/iconIPhone.png", 
    Instructions    = "https://github.com/amg0/IPhoneLocator",
    AutoUpdate      = "0",
    VersionMajor    = "not",
    VersionMinor    = "installed",
    id              = 4686,
--    timestamp       = os.time(),
    Files           = {},
    Devices         = {
      {
        DeviceFileName  = "D_IPhone.xml",
        DeviceType      = "urn:schemas-upnp-org:device:IPhoneLocator:1",
        ImplFile        = "I_IPhone.xml",
        Invisible       =  "0",
--        CategoryNum = "1",
--        StateVariables = "..." -- see luup.create_device documentation
      },
    },
    Repository      = {
      {
        type      = "GitHub",
        source    = "amg0/IPhoneLocator",
        default   = "master",                   -- "development" or "master" or any tagged release
  --      folders = {                     -- these are the bits we need
  --        "subdir1",
  --        "subdir2",
  --      },
  --      pattern = "[DILS]_%w+%.%w+"     -- Lua pattern string to describe wanted files
        pattern   = "IPhone",                   -- pattern match string for required files
      },
  -- other stuff can go here
    }
  }


-------------------------------------------------------
--
-- the update_plugin action is implemented in two parts:
-- <run>  validity checks, etc.
-- <job>  phased download, with control returned to scheduler between individual files
--

local ipl         -- the plugin metadata
local next_file   -- download iterator
local target      -- location for downloads

function update_plugin_run(p)
  _log "starting <run> phase..."
  p.metadata = p.metadata or json.encode (IPhone)     -- TESTING ONLY!
  ipl = json.decode (p.metadata)
  
  if type (ipl) ~= "table" then 
    _log "invalid plugin metadata"
    return false                            -- failure
  end
  
  local r = (ipl.Repository or {}) [1]
  if not (r and r.source) then 
    _log "invalid repository metadata"
    return false
  end
  
  target = table.concat {ludl_folder , "plugins", pathSeparator}
  lfs.mkdir (target)
  local updater = GitHub (r.source, target)
  
  local rev = p.Version or r.default    -- a "default", for when the Update box has no entry
  
  _log ("downloading", ipl.id, "rev", rev) 
  local folders = r.folders or {''}    -- these are the bits of the repository that we want
  next_file = updater.get_release_by_file (rev, folders, r.pattern) 
  
  display ("Downloading...", ipl.Title or '?')
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

local total = 0     -- total file transfer size

function update_plugin_job()
  
  local status, name, size = next_file()
  if status then
    if status ~= 200 then
      _log "download failed"
      --tidy up
      return jobstate.Error,0
    end
    local column = "%6d %s"
    _log (column:format (size, name))
    total = total + size
    return jobstate.WaitingToStart,0        -- reschedule immediately
  else
    -- finish up
    _log ("Total size", total)
 
    -- I generally deplore the use of os.execute (won't work on every platform?), 
    -- but in this case it is much kinder on the file system to move, rather than copy/delete. 
    _log ("updating icons in ", icon_folder, "...")
    os.execute (table.concat {"mv ", target, "*.png ", icon_folder})
    _log ("updating device files in", ludl_folder, "...")
    os.execute (table.concat {"mv ", target, "*.* ", ludl_folder})
    --TODO: possible pluto-lzo?
   
    _log "update completed"
    
    install_if_missing (ipl)
    display ('','')
    return jobstate.Done,0        -- finished job
  end
end


-------------------------------------------------------
--
-- Alt App Store
--

-- HTTP request handler
function HTTP_AltAppStore (_, p)
  local err, msg, job, arg = luup.call_action (SID.apps, "update_plugin", p, devNo)
  err = tostring(err)
  msg = tostring (msg)
  job = tostring (json.encode (job))
  arg = tostring (json.encode (arg))
  local content = " status = %s\n message = %s\n job = %s\n arg = %s\n"
  return content: format (err,msg,job, arg), "text/plain"
end

-- plugin initialisation
function init (d)
  devNo = d
  
  _log "starting..."
  luup.register_handler ("HTTP_AltAppStore", "update_plugin")
  display (ABOUT.NAME,'')
  
  set_failure (0)
  return true, "OK", ABOUT.NAME
end
 
-----

