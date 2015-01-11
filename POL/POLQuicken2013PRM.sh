#!/bin/bash
# Distribution used to test : Linux Mint 17 x86_64
# Author : Jeff Kowalski
# Dependencies : taskset, locate
# Script License: GPL License v3

# see scripting documentation at http://www.playonlinux.com/en/documentation.html

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"

TITLE="Quicken Premier 2013"
PREFIX="quicken"
WORKING_WINE_VERSION="1.7.34"

# initialize
POL_SetupWindow_Init
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "Intuit, Inc." "http://quicken.intuit.com" "Jeff Kowalski" "$PREFIX"

### FIXME - why dont these work? check_one is unimplemented contrary to the docs
#check_one "taskset" "taskset"
#check_one "locate" "locate"
#POL_SetupWindow_missing

# create prefix directory
POL_System_TmpCreate "$PREFIX"
POL_Wine_SelectPrefix "$PREFIX"
POL_System_SetArch "x86"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# install extra components
POL_Call POL_Install_dotnet20
POL_Call POL_Install_tahoma
POL_Call POL_Install_FontsSmoothRGB
POL_Call POL_Install_LunaTheme
Set_OS "win7"

POL_Wine_reboot

# keep Quicken running on a single CPU to avoid heap corruption
export BEFORE_WINE="taskset -c 0"

# install main program
DEFAULT_INSTALLER=$(locate QW13PRM.exe | grep -v Trash | head -n 1)
### FIXME - why doesn't browse respect the default argument?
POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run.')" "$TITLE" "$DEFAULT_INSTALLER"
POL_SetupWindow_message "$(eval_gettext 'Warning: You must un-tick the checkbox [Launch Quicken 2013] when installation is complete.')" "$TITLE"
POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"
POL_Wine start /unix "$APP_ANSWER"
POL_Wine_WaitExit "$TITLE"

# install patches
POL_SetupWindow_message "$(eval_gettext 'Install patches')" "$TITLE"
POL_SetupWindow_InstallMethod "LOCAL,DOWNLOAD"
if [ "$INSTALL_METHOD" = "LOCAL" ]
then
    DEFAULT_INSTALLER=$(locate QW2013R12MPatch.exe | grep -v Trash | head -n 1)
    ### FIXME - why doesn't browse respect the default argument?
    POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run.')" "$TITLE" "$DEFAULT_INSTALLER"
elif [ "$INSTALL_METHOD" = "DOWNLOAD" ]
then
    pushd "$POL_System_TmpDir"
    POL_Download "http://http-download.intuit.com/http.intuit/CMO/quicken/patch/QW2013R12MPatch.exe" "ce22e5123aa97993b1a7e05ce0751a81"
    APP_ANSWER="$POL_System_TmpDir/QW2013R12MPatch.exe"
    popd
fi
POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"
POL_Wine start /unix "$APP_ANSWER"
POL_Wine_WaitExit "$TITLE"

# create shortcut
POL_Shortcut "qw.exe" "$TITLE"

# keep Quicken running on a single CPU to avoid heap corruption
POL_Shortcut_InsertBeforeWine "$TITLE" 'export BEFORE_WINE="taskset -c 0"'

# adjust default register font face in Quicken Config file
sed -i "/FontFace=/d; s/\[Quicken\]/&\nFontFace=Droid Sans/;" "$WINEPREFIX/drive_c/users/Public/Application Data/Intuit/Quicken/Config/Quicken.ini"

# adjust DPI to 120 (78 hex), making fonts a little larger
### FIXME - these helpers work for only string values, not dwords, so we need to use the raw UpdateRegistry calls below
#POL_Wine_UpdateRegistryWinePair "Fonts" "LogPixels" "dword:00000078"
#POL_Wine_UpdateRegistryPair "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Hardware Profiles\\Current\\Software\\Fonts" "LogPixels" "dword:00000078"
POL_Wine_UpdateRegistry regkey <<- _EOFINI_
[HKEY_CURRENT_USER\\Software\\Wine\\Fonts]
"LogPixels"=dword:00000078
_EOFINI_
POL_Wine_UpdateRegistry regkey <<- _EOFINI_
[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Hardware Profiles\\Current\\Software\\Fonts]
"LogPixels"=dword:00000078
_EOFINI_

# clean up
POL_System_TmpDelete
POL_SetupWindow_Close

exit
