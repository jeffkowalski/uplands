#!/bin/bash
# Distribution used to test : Linux Mint 17 x86_64
# Author : Jeff Kowalski
# Dependencies : taskset, locate, 7x, perl
# Script License: GPL License v3

# see scripting documentation at http://www.playonlinux.com/en/documentation.html

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"

TITLE="Quicken Premier 2016"
PREFIX="quicken2016"
WORKING_WINE_VERSION="1.9.22"

# initialize
POL_SetupWindow_Init
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "Intuit, Inc." "http://quicken.intuit.com" "Jeff Kowalski" "$PREFIX"

### FIXME - why dont these work? check_one is unimplemented contrary to the docs
#check_one "taskset" "taskset"
#check_one "locate" "locate"
#check_one "7z", "7z"
#check_one "perl" "perl"
#POL_SetupWindow_missing

# create prefix directory
POL_System_TmpCreate "$PREFIX"
POL_Wine_SelectPrefix "$PREFIX"
POL_System_SetArch "x86"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# install extra components
POL_Call POL_Install_corefonts
POL_Call POL_Install_dotnet40
POL_Call POL_Install_tahoma
POL_Call POL_Install_FontsSmoothRGB
POL_Call POL_Install_LunaTheme
Set_OS "win7"

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

POL_Wine_reboot

# keep Quicken running on a single CPU to avoid heap corruption
export BEFORE_WINE="taskset -c 0"

# install main program
DEFAULT_INSTALLER=$(locate Intuit_Quicken_Premier_2016.exe | grep -v Trash | head -n 1)
### FIXME - why doesn't browse respect the default argument?
POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run.')" "$TITLE" "$DEFAULT_INSTALLER"
POL_SetupWindow_message "$(eval_gettext 'Warning: You must un-tick the checkbox [Launch Quicken 2016] when installation is complete.')" "$TITLE"
POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"

# extract executable and patch it to remove prevent
# installation of Amyuni PDF printer, which causes failure
#   Error Code: 1797
#   Unknown printer driver.
7z x "$APP_ANSWER"
perl -pi.bak -0777e 's/NOT REMOVE="ALL"InstallPDFDriver/NOT_REMOVE="ALL"InstallPDFDriver/' "DISK1/Quicken 2016.msi"
POL_Wine start /unix DISK1/Setup.exe
POL_Wine_WaitExit "$TITLE"

# create shortcut
POL_Shortcut "qw.exe" "$TITLE"

# keep Quicken running on a single CPU to avoid heap corruption
POL_Shortcut_InsertBeforeWine "$TITLE" 'export BEFORE_WINE="taskset -c 0"'

# adjust default register font face in Quicken Config file
sed -i "/FontFace=/d; s/\[Quicken\]/&\nFontFace=Droid Sans/;" "$WINEPREFIX/drive_c/users/Public/Application Data/Intuit/Quicken/Config/Quicken.ini"

# clean up
POL_System_TmpDelete
POL_SetupWindow_Close

exit
