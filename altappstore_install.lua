-- first-time download and install ofAltAppStore files from GitHub
-- this code should be run on a Vera in the Lua Test Code window
-- 2016.11.16 @akbooer
-- 2018.02.24 upgrade SSL encryption to tls v1.2 after GitHub deprecation of v1 protocol


local x = os.execute
local p = print

p "AltAppStore_install   2016.11.16   @akbooer"

local https = require "ssl.https"
local ltn12 = require "ltn12"

p "getting latest AltAppStore version tar file from GitHub..."

local _, code = https.request{
  url = "https://codeload.github.com/akbooer/AltAppStore/tar.gz/master",
  sink = ltn12.sink.file(io.open("/tmp/altappstore.tar.gz", "wb")),
  protocol = "tlsv1_2",
}

assert (code == 200, "GitHub download failed with code " .. code)
  
p "un-zipping download files..."

x "tar -xz -f /tmp/altappstore.tar.gz -C /etc/cmh-ludl/" 
x "mv /etc/cmh-ludl/AltAppStore-master/*_* /etc/cmh-ludl/"

p "creating AltAppStore plugin device"

local s,c = luup.inet.wget (table.concat {
    "http://127.0.0.1:3480/data_request?id=action",
    "&output_format=json",
    "&DeviceNum=0",
    "&serviceId=urn:micasaverde-com:serviceId:HomeAutomationGateway1",
    "&action=CreateDevice",
    "&Description=AltAppStore",
    "&UpnpDevFilename=D_AltAppStore.xml",
    "&UpnpImplFilename=I_AltAppStore.xml",
    "&RoomNum=0",
    "&Reload=1",
  })

p ("status = " .. (s or '?'))
p ("response = " .. (c or '?'))
p "done!"

-----
