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
|DeviceType	|UPnP Device type, eg. `urn:schemas-upnp-org:device:altui:1`.  NB: _very important that this type matches that used in the device.xml file_
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

##Other points to note

`AltUI` itself doesn't have access to the MiOS store.  Whilst it can get information on plugins which are already installed on Vera, it has no way of knowing the plugin id of any other one.  That's all it needs to tell Vera to fetch it.  This is the function of the `Vera` download button in the store.

`openLuuup`, on the other hand, has no way at all of accessing the MiOS store (it can access to the MiOS Trac repository for some plugins, indeed, AltUI itself was originally fetched from there) so there needs to be another way...

`AltAppStore` can download files from a GitHub repository to either Vera or openLuup using the Alt button.  Aside from the pre-installed plugins in openLuup, this is the only automatic way to download new plugins to openLuup.

The store has a side-benefit for Vera-only developers, since publication is immediate, and there is no indeterminate wait for the new version to be approved.  Also, if you think that the AltAppStore configuration is convoluted, you should try publishing through the MiOS store... 

Once AltAppStore has a plugin configured you can almost forget about it, unless you want to update your pull-down menu for new tagged releases.  Also, once loaded, there's enough information for openLuup to update from GitHub directly, without the intervention of the store.  Simply press the `Update` button on the plugin page against a particular plugin.  If you know the repository organization, you can also specify, via the `Update box`, a particular branch (eg. "master", "development", ...) or tagged release (eg. "v1.1") before clicking the Update button.
