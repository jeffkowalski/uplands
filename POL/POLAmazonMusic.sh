#!/bin/bash
# Distribution used to test : Ubuntu Gnome 15.04
# Author: adapted by landiatico, based on Amazon Kindle installer by Fekir and mstern
# See https://www.playonlinux.com/en/app-2640-Amazon_Music.html


# Edited wine version and downloaded installer [mstern dot pds at gmail dot com]

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"

TITLE="Amazon Music"
PREFIX="amazon_music"
WORKING_WINE_VERSION="1.9.20"

# initialize
POL_SetupWindow_Init
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "Amazon" "http://www.amazon.com" "Jeff Kowalski" "$PREFIX"

# create prefix directory
POL_System_TmpCreate "$PREFIX"
POL_Wine_SelectPrefix "$PREFIX"
POL_System_SetArch "x86"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# install extra components
POL_Call POL_Install_corefonts
Set_OS "vista"

POL_Wine_reboot

# install main program
POL_SetupWindow_InstallMethod "LOCAL,DOWNLOAD"
if [ "$INSTALL_METHOD" = "LOCAL" ]
then
    pushd "$HOME"
    POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run')" "$TITLE"
elif [ "$INSTALL_METHOD" = "DOWNLOAD" ]
then
    pushd "$POL_System_TmpDir"
    POL_Download "https://images-na.ssl-images-amazon.com/images/G/01/digital/music/morpho/installers/20151008/17125040c0/AmazonMusicInstaller.exe" "ea6fa40e817ac436eea54b9f9addb963"
    APP_ANSWER=$POL_System_TmpDir/AmazonMusicInstaller.exe
    popd
fi
rm -f "$WINEPREFIX/drive_c/windows/winsxs/manifests/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.4148_none_deadbeef.manifest"
POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"
POL_Wine start /unix "$APP_ANSWER"
POL_Wine_WaitExit "$TITLE"

# create shortcut
POL_Shortcut "Amazon Music.exe" "$TITLE"

# clean up
POL_System_TmpDelete
POL_SetupWindow_Close

exit
