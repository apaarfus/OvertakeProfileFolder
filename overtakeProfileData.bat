:: overtakeProfileData.bat
:: Author:		Alex Paarfus <apaarfus@wtcox.com>
:: Date:		2019-03-20
::
:: Takes ownership and applies full-control permissions to a given
:: directory (and all subs) -- for use when deprecating old user
:: data.
::
:: Requires:
::		icacls
::-----------------------------------------------------------------------------

:: Env Opts
@echo off
setlocal enableextensions
::-----------------------------------------------------------------------------

:: Check for Admin Rights
net session >nul 2>&1
if not errorlevel 0 (
	echo Error: ADMIN REQUIRED
	ping 127.0.0.1 -n 5 >nul
	goto :eof
)
::-----------------------------------------------------------------------------

:: Vars
set "datestamp=%date:~10,4%-%date:~4,2%-%date:~7,2%"
set "_rdir=%systemdrive%\Users"
set "_pun=oldUser"
set "_nun=newUser"
set "_permission=f"
set "_inherit=0"
set "_recurse=0"
set "_FAIL=0"
set "_force=0"
set "_take=0"
set "_apply=0"
set "_icINH=/inheritance:e"
set "_icGNT=/grant:r"
::-----------------------------------------------------------------------------

:: Handle Arguments
if "%~1."=="." goto :eof
:paLoopStart
	:: Check to exit loop
	if /i "%~1."=="." goto :paLoopEnd
	if %_FAIL% equ 1 goto :paLoopEnd
	:: Determine if "named" argument
	cd .
	echo "%~1" | find ":" >nul
	if errorlevel 0 goto :namedArg
	cd .	
	:: Switches
	if /i "%~1"=="/h" call :showHelp & goto :paLoopEnd
	if /i "%~1"=="/?" call :showHelp & goto :paLoopEnd
	if /i "%~1"=="/i" set "_inherit=1" & goto :paLoopNext
	if /i "%~1"=="/r" set "_recurse=1" & goto :paLoopNext
	if /i "%~1"=="/f" set "_force=1" & goto :paLoopNext
	if /i "%~1"=="/o" set "_take=1" & goto :paLoopNext
	if /i "%~1"=="/a" set "_apply=1" & goto :paLoopNext
	echo ERROR UNKNOWN ARG "%~1"
	goto :paLoopEnd
	:: "Named" Arguments
	:nameArg
	for /f "tokens=1,2* delims=:" %%a in ("%~1") do call :paNamedArgs "%%~a" "%%~b"
	goto :paLoopNext
	:paLoopNext
	shift
	goto :paLoopStart
:paLoopEnd
::-----------------------------------------------------------------------------

:: Run
if %_FAIL% equ 0 (
	:: Check Options
	call :checkOpts
	:: Take ownership && apply permissions
	if %_take% equ 1 call :takeOwnership
	if %_apply% equ 1 call :applyPermissions
)

:: Clear Memory and quit
call :usv
goto :eof
::-----------------------------------------------------------------------------

:: Functions
:: Take Ownership of files
:takeOwnership
	set "cmdOpts="
	if %_recurse% equ 1 set "cmdOpts=/t "
	if %_force% equ 1 set "cmdOpts=/c"
	cd .
	icacls "%_rdir%\%_pun%" /setowner "%_nun%" %cmdOpts% >nul
	if not errorlevel 0 (
		set "cmdOpts="
		if %_recurse% equ 1 set "cmdOpts=/r"
		cmd /k runas /user:%_nun% takeown /f "%_rdir%\%_pun%" %cmdOpts% /d y 
	)
	set "cmdOpts="
goto :eof
::-----------------------------------------------------------------------------

:: Apply Permissions
:applyPermissions
	set "cmdOpts="
	if %_recurse% equ 1 set "cmdOpts=/t "
	if %_inherit% equ 1 set "cmdOpts=%_icINH% "
	if %_force% equ 1 set "cmdOpts=/c"
	icacls "%_rdir%\%_pun%" %cmdOpts% %_icGNT% "%_nun%:%_permission%" >nul
	set "cmdOpts="
goto :eof
::-----------------------------------------------------------------------------

:: Parse "Named" Args -- %1 == switch, %2 == arg
:paNamedArgs
	if "%~1."=="." goto :eof
	if "%~2."=="." goto :eof
	:: Parse
	if /i "%~1"=="/d" set "_rdir=%~2" & goto :eof
	if /i "%~1"=="/p" set "_permission=%~2" & goto :eof
	if /i "%~1"=="/pun" set "_pun=%~2" & goto :eof
	if /i "%~1"=="/nun" set "_nun=%~2" & goto :eof
	echo ERROR, UNKNOWN ARG "%~1:%~2"
goto :eof
::-----------------------------------------------------------------------------

:: Check Options
:checkOpts
	:: Null Value checks
	if "%datestamp%."=="." set "_FAIL=1" & goto :notifyUser
	if "%_rdir%."=="." set "_FAIL=2" & goto :notifyUser
	if "%_pun%."=="." set "_FAIL=3" & goto :notifyUser
	if "%_nun%."=="." set "_FAIL=4" & goto :notifyUser
	if "%_permission%."=="." set "_FAIL=5" & goto :notifyUser
	if "%_inherit%."=="." set "_FAIL=6" & goto :notifyUser
	if "%_recurse%."=="." set "_FAIL=7" & goto :notifyUser
	if "%_force%."=="." set "_FAIL=8" & goto :notifyUser
	if "%_take%."=="." set "_FAIL=9" & goto :notifyUser
	if "%_apply%."=="." set "_FAIL=10" & goto :notifyUser
	if "%_icINH%."=="." set "_FAIL=11" & goto :notifyUser
	if "%_icGNT%."=="." set "_FAIL=12" & goto :notifyUser
	
	:: Directory Existence
	if not exist "%_rdir%" set "_FAIL=13" & goto :notifyUser
	if not exist "%_rdir%\%_pun%" set "_FAIL=14" & goto :notifyUser
	if not exist "%_rdir%\%_nun%" set "_FAIL=15" & goto :notifyUser
	
	:: Validity of settings
	:: Permissions
	cd .
	echo "%_permission%" | findstr /i /r /c:"[dfnmrw]x?" >nul 2>&1
	if errorlevel 0 goto :eof
	set "_FAIL=16"
	goto :notifyUser
	
	
	:: Notify User of their error
	:notifyUser
	if %_FAIL% equ 0 goto :eof
	if %_FAIL% equ 1 echo NO DATESTAMP & goto :eof
	if %_FAIL% equ 2 echo NO ROOT DIR & goto :eof
	if %_FAIL% equ 3 echo NO PREV USER & goto :eof
	if %_FAIL% equ 4 echo NO NEW USER & goto :eof
	if %_FAIL% equ 5 echo NO PERMS & goto :eof
	if %_FAIL% equ 6 echo NO INHERIT & goto :eof
	if %_FAIL% equ 7 echo NO RECURSE & goto :eof
	if %_FAIL% equ 8 echo NO CONTINUE & goto :eof
	if %_FAIL% equ 9 echo NO TAKE & goto :eof
	if %_FAIL% equ 10 echo NO APPLY & goto :eof
	if %_FAIL% equ 11 echo BAD INHERIT OPT & goto :eof
	if %_FAIL% equ 12 echo BAD GRANT OPT & goto :eof
	if %_FAIL% equ 13 echo NOEXIST ROOT DIR & goto :eof
	if %_FAIL% equ 14 echo NOEXIST PREV DIR & goto :eof
	if %_FAIL% equ 15 echo NOEXIST NEW DIR & goto :eof
	if %_FAIL% equ 16 echo BAD PERMISSIONS & goto :eof
goto :eof
::-----------------------------------------------------------------------------

:: Show Help
:showHelp
	echo overtakeProfileData.bat ^[Options^]
	echo Please note that all options must be:
	echo     -Encapsulated in Double Quotes ^("/x", "/y:name"^)
	echo     -Seperated by spaces
	echo         -GOOD:  "/x" "/y:name"
	echo         -BAD :  "/xy:name"
	echo.
	echo Options:
	echo     /h, /?                    Show this Help Message
	echo     /i                        Enable Inheritance
	echo     /r                        Enable Recursion
	echo     /f                        Continue on error^(s^)
	echo     /o                        Enable Ownership Takeover
	echo     /a                        Enable application of permissions
	echo     /d:^<path^>               Path to the root directory of User Profiles
	echo     /p:^<perm^>               Permission type to apply to data
	echo                                   -See Microsoft's docs on iCACLS
	echo     /pun:^<name^>             Previous Username ^(profile name^)
	echo     /nun:^<name^>             New Username ^(ownership/permissions^)
	echo.
goto :eof
::-----------------------------------------------------------------------------

:: Clear Memory
:usv
	set "datestamp="
	set "_rdir="
	set "_pun="
	set "_nun="
	set "_permission="
	set "_inherit="
	set "_recurse="
	set "_FAIL="
	set "_force="
	set "_take="
	set "_apply="
	set "_icINH="
	set "_icGNT="
goto :eof
::-----------------------------------------------------------------------------
