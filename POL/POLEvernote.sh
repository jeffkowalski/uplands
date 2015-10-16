#!/bin/bash
# Distribution used to test : Linux Mint 17 x86_64
# Author : Jeff Kowalski
# Dependencies : taskset
# Script License: GPL License v3

# see scripting documentation at http://www.playonlinux.com/en/documentation.html

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"

TITLE="Evernote"
PREFIX="evernote"
WORKING_WINE_VERSION="1.7.53"

# initialize
POL_SetupWindow_Init
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "Evernote, Inc." "http://evernote.com" "Jeff Kowalski" "$PREFIX"

### FIXME - why dont these work? check_one is unimplemented contrary to the docs
#check_one "taskset" "taskset"
#POL_SetupWindow_missing

# create prefix directory
POL_System_TmpCreate "$PREFIX"
POL_Wine_SelectPrefix "$PREFIX"
POL_System_SetArch "x86"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# install extra components
#POL_Call POL_Install_dotnet20
POL_Call POL_Install_tahoma
POL_Call POL_Install_FontsSmoothRGB
POL_Call POL_Install_LunaTheme
Set_OS "win7"

POL_Wine_reboot

# keep Evernote running on a single CPU to avoid heap corruption
export BEFORE_WINE="taskset -c 0"

# install main program
POL_SetupWindow_InstallMethod "LOCAL,DOWNLOAD"
if [ "$INSTALL_METHOD" = "LOCAL" ]
then
    POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run.')" "$TITLE"
elif [ "$INSTALL_METHOD" = "DOWNLOAD" ]
then
    pushd "$POL_System_TmpDir"
    POL_Download "http://evernote.com/download/get.php?file=Win"
    # POL download filename is the tail of the URL; move to more reasonable name
    mv "get.php?file=Win" setup.exe
    APP_ANSWER=$POL_System_TmpDir/setup.exe
    popd
fi
POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"
POL_Wine start /unix "$APP_ANSWER"
POL_Wine_WaitExit "$TITLE"

# relink database
rm -r "$WINEPREFIX/drive_c/users/$USER/Local Settings/Application Data/Evernote"
mkdir "$WINEPREFIX/drive_c/users/$USER/Local Settings/Application Data/Evernote"
ln -s /mnt/SiliconPower/Evernote "$WINEPREFIX/drive_c/users/$USER/Local Settings/Application Data/Evernote/"

# create shortcut
POL_Shortcut "Evernote.exe" "$TITLE"

# keep application running on a single CPU to avoid heap corruption
POL_Shortcut_InsertBeforeWine "$TITLE" 'export BEFORE_WINE="taskset -c 0"'

# clean up
POL_System_TmpDelete
POL_SetupWindow_Close

exit
