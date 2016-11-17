# AltAppStore
Altui App Store plugin for Vera

From release v1.58.1763 of AltUI, you now have an alternative way to install and update plugins on either your Vera 
or openLuup systems.

AltAppStore is part of a normal openLuup install, but since it is not in the MiOS app store, an initial manual 
installation is required on UI5 or UI7 systems.  A Lua script file `altappstore_install.lua`, which should be run in Vera's 
Lua Test Code window, is part of this repository.

## Publishing a Plugin in the AltAppStore

To publish a new plugin, or to edit an existing one, go to the `More > App Store` page and click on the `Publish` button at the lower left of the screen.

This takes you to a screen which starts with a Publish Application section, allowing you to create a new one, or modify an existing one after selecting a version, and below that is an extended menu of items (see attachment.)  There's a fair amount to fill in, but that's because the UPnP structures required to define a plugin are quite complex.  However, any seasoned application developer who has used the MiOS App Store to publish will be familiar with this, and hopefully find it a bit more user-friendly.

## Edit Application Properties

|Parameter|Function |
|---------|---------|
App ID	|a short identifier for the plugin.  If this is one which is already in the MiOS App Store, it would be good to use the same numeric ID
App Title	|the title of your plugin.  It will also be used as the device name for the first plugin device created by the install process.
Description	|slightly longer (but still short) text describing the plugin.  This appears on the banner on the App Store page.
Instructions	|fully-qualified URL pointing to a page (often GitHub) with more extensive documentation.
AllowMultiple	|0 or 1 flag indicating the possibility of having multiple plugin devices.
AutoUpdate	|0 or 1 flag.  Unused at present, since there is no auto-update yet, except for AltUI itself, which checks for new versions on page refreshes.
Icon	|HTTP reference to a `xxx.png` icon file
VersionMajor	|short, often numeric, version number
VersionMinor	|ditto

## Device

|Parameter|Function |
|---------|---------|
|DeviceFilename	|UPnP Device `D_xxx.xml` file
|DeviceType	|UPnP Device type, eg. `urn:schemas-upnp-org:device:altui:1`
|ImplFile	|UPnP Implementation `I_xxx.xml` file
|Invisible	|0 or 1 flag indicating device visibility (keep this 0)

##GitHub

|Parameter|Function |
|---------|---------|
pattern	|this may be blank, but otherwise contains a Lua string pattern which matches ALL the files you want to download from your GitHub repository, which often contains lots of other things (documentation, licence, folders, ...) which you don't want to download.  If you have a bit of discipline in naming your files (eg. AltUI files all contain "ALTUI") then this is easy.  If you stick to the traditional Vera naming convention for device files, then this can be `"[DIJLS]_%w+%.%w+"`
source	|a string of the form `"amg0/ALTUI"`, being simply `<your username>/<your GitHub repository for the plugin>`
folders	|this may be blank, in which case the files matching the pattern (above) are downloaded from the root folder of the repository.  However, multiple folders may also be defined, the top level one being simply `""`.  Example: `"luup_files, more_files"` or even  `",subfolder"` for top level + subfolder
release	|release name or GitHub tag or branch name

##Vera Store

|Parameter|Function |
|---------|---------|
release	| MCV version number, See the attached screen to determine the version number of your plugin version in MCV store...
