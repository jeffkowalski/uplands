#!/bin/bash

# See https://appdb.winehq.org/objectManager.php?sClass=version&iId=25161&iTestingId=78464

# to fix
#    err:module:load_builtin_dll failed to load .so lib for builtin Lwinex11.drv: libSM.so.6: cannot open shared object file: No such file or directory
# sudo dpkg --add-architecture i386
# sudo apt-get install libsm6:i386


# Author : Tinou

# CHANGELOG
# [Quentin PÂRIS] (2012-05-05 14-45)
#   Wine version set to 1.5.3, Outlook 2010 compatiblity
# [Quentin PÂRIS] (2012-05-05 15-05)
#   Check winbind presence on Linux, required to install
#   Adding gettext support
# [Quentin PÂRIS] (2012-05-12 18-36)
#   Requires 4.0.18
# [SuperPlumus] (2013-06-09 14-44)
#   gettext

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"

TITLE="Microsoft Office 2010"
PREFIX="Office2010"
WORKING_WINE_VERSION="1.5.29"

# initialize
POL_GetSetupImages "http://files.playonlinux.com/resources/setups/Office/top.jpg" "http://files.playonlinux.com/resources/setups/Office/left.png" "$TITLE"
POL_SetupWindow_Init
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "Microsoft" "http://www.microsoft.com" "Quentin PÂRIS" "$PREFIX"

POL_RequiredVersion 4.0.18 || POL_Debug_Fatal "$TITLE won't work with $APPLICATION_TITLE $VERSION\nPlease update"

if [ "$POL_OS" = "Linux" ]; then
    wbinfo -V || POL_Debug_Fatal "Please install winbind before installing $TITLE"
fi

# create prefix directory
POL_System_TmpCreate "$PREFIX"
POL_Wine_SelectPrefix "$PREFIX"
POL_System_SetArch "x86"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# install extra components
#POL_Call POL_Install_dotnet40
#POL_Call POL_Install_msxml6
#POL_Call POL_Function_OverrideDLL native msxml6
#POL_Call POL_Install_riched20
#POL_Call POL_Function_OverrideDLL native riched20
#POL_Call POL_Function_OverrideDLL native,builtin urlmon
Set_OS "winxp"
POL_Wine_reboot

# install main program
POL_SetupWindow_InstallMethod "LOCAL,DVD"
if [ "$INSTALL_METHOD" = "DVD" ]; then
        POL_SetupWindow_cdrom
        POL_SetupWindow_check_cdrom "x86/setup.exe" "setup.exe"
        APP_ANSWER="$CDROM_SETUP"
        cd "$CDROM"
else
        POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run')" "$TITLE"
fi

POL_SetupWindow_wait "$(eval_gettext 'Please wait while $TITLE is installed.')" "$TITLE"
POL_Wine start /unix "$APP_ANSWER"
POL_Wine_WaitExit "$TITLE"

sleep 2

POL_Wine_reboot

POL_Call POL_Function_OverrideDLL native riched20
POL_Call POL_Function_OverrideDLL native,builtin rpcrt4
POL_Call POL_Function_OverrideDLL native,builtin winhttp
POL_Call POL_Function_OverrideDLL native,builtin wininet
POL_Call POL_Install_dotnet40

# create shortcuts
#POL_Shortcut "WINWORD.EXE" "Microsoft Word 2010"
#POL_Shortcut "EXCEL.EXE" "Microsoft Excel 2010"
#POL_Shortcut "POWERPNT.EXE" "Microsoft Powerpoint 2010"
#POL_Shortcut "ONENOTE.EXE" "Microsoft OneNote 2010"
POL_Shortcut "OUTLOOK.EXE" "Microsoft Outlook 2010"

#POL_Extension_Write doc "Microsoft Word 2010"
#POL_Extension_Write docx "Microsoft Word 2010"
#POL_Extension_Write xls "Microsoft Excel 2010"
#POL_Extension_Write xlsx "Microsoft Excel 2010"
#POL_Extension_Write ppt "Microsoft Powerpoint 2010"
#POL_Extension_Write pptx "Microsoft Powerpoint 2010"

POL_SetupWindow_browse "$(eval_gettext 'Please select the registry file to import')" "$TITLE"
POL_Wine regedit "$APP_ANSWER"

POL_SetupWindow_message "$(eval_gettext '$TITLE has been installed successfully\n\nIf an installation Windows prevent your programs from running, you must remove and reinstall $TITLE')" "$TITLE"




# clean up
POL_System_TmpDelete
POL_SetupWindow_Close
exit
