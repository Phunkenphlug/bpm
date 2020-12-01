@echo off
setlocal
:: 2019.09.07 StW: Initial Relase V1.1
:: 2019.09.23 StW: Relase V1.2 - Homeserver added local
:: 2019.09.23 StW: Relase V1.3 - silentdb (winpm-silent.lst) feature added 
:: 2020.05.24 StW: Relase V1.4 - voidtools everything feature added
:: 2020.06.14 StW: Relase V1.41- edit mode for silentlist

set ver=1.41

:: Everything settings
set everything=0
REM tasklist | find /I "everything" | find /I "console">NUL && set everything=1
set eslist=%~dp0es.lst
set instlist=%~dp0winpm-inst.lst

set packpath=\\homeserver.local\data\install
set winpmpass=DontUseThisPasspharse
set silentlist=%~dp0winpm-silent.lst

echo *** try new features: -find and -updatelist ***

if "x%type%"=="x" set type=exe
if /I "%1" == "-type" set type=%2& shift & shift
if /I "%1" == "-list" call :list %2
if /I "%1" == "-del" for /R %packpath% %%i in (*%2*.%type%) do @erase %%~dpnxi
if /I "%1" == "-get" dir "%packpath%\%2*.%type%" /S/B
if /I "%1" == "-updatelist" call :updatelist&exit /b
if /I "%1" == "-find" call :findpkg "%2"&exit /b
REM if /I "%1" == "-list" for /F %%i in ('findstr /I /R %2 "%instlist%"') do @for /F "delims=; tokens=1-2" %%x in (%~dp0winpm-silent.lst) do @echo %%~dpnxi|findstr /I /R %%x && echo %%~dpnxi (*Silent)
REM if /I "%1" == "-install" for /F %%i in ('findstr /I /R %2 "%instlist%"') do @echo Installing %%~nxi ...& rem call :install %%i %3 %4 %5 %6 %7 %8&exit /b
REM Show if silent switch available
REM if /I "%1" == "-list" for /R %packpath% %%i in (*%2*.%type%) do @for /F "delims=; tokens=1-2" %%x in (%~dp0winpm-silent.lst) do @echo %%~dpnxi|findstr /I /R %%x && echo %%~dpnxi (*Silent)
if /I "%1" == "-install" for /F "delims=" %%i in ('dir %packpath%\*%2*.%type% /S /B /O-D') do @echo Installing %%~nxi ...& call :install %%i %3 %4 %5 %6 %7 %8&exit /b
if /I "%1" == "-uninstall" for /R %packpath% %%i in (*%2*.%type%) do @echo Uninstalling %%~nxi ...& call "%~dpnx0" -winpm x %%i&exit /b
if /I "%1" == "-make" call :makeWinPM %2&exit /b
if /I "%1" == "-unpack" call :unpackWinPM %2&exit /b
if /I "%1" == "-WinPM" call :winpm %2 %3 %4&exit /b
if /I "%1" == "-edit" start notepad %silentlist% &exit /b
if /I "%1" == "-rename" call :rename %2&exit /b
if /I "%1" == "-push" call :push %2&exit /b
if /I "%1" == "-pull" for /R %packpath% %%i in (*%2*.%type%) do @call :pull %%~dpnxi
if "%1" == "" goto :syntax
goto :eof

:syntax
echo.
echo *** Windows Package-Manager V%ver% ***
echo PackageSource: %packpath%
echo PackageType:   %type%
echo.
echo Usage: %~nx0 [^-type exe^|msi^|7z^|WinPM] ^-list^|-del^|-install packagename ^[parameter]
echo              Show all, delete first or install first package(s) from source
echo.
echo        %~nx0 ^-push^|pull package
echo              Manage installtionfiles from and to source
echo.
echo        %~nx0 ^-rename Packagefile (only EXE)
echo              Get versionnummer and rename file from ProdSetup.exe to ProdSetup_V1.23.exe
echo.
echo        *** Experimental ***
echo        %~nx0 ^-edit
echo              Edit Silent-Install-list
echo.
echo        %~nx0 ^-make WinPM-Packagename
echo              Generate a crypted WinPM-Package from the current Directory
echo.
echo        %~nx0 ^-unpack WinPM-Packagename
echo              Unpack a crypted WinPM-Package into the current Directory
echo.
echo        %~nx0 -WinPM [-l^|-u^|-s^|-x^|-d]  WinPM-Packagename
echo              -l Show content of the _INSTALL_-File of the WinPM
echo              -p Show stored Productname
echo              -u Open Homepage of Product
echo              -s Silent install
echo              -x Silent uninstall
echo              -d download Productfiles from Homepage (WGet needed!)
echo.
echo.
echo        Example:
echo        %~nx0 -install pdf24 /silent
echo              silently install the first pdf24-creator from source
echo        %~nx0 -install winrar*590
echo              install the first named winrar AND 590 from source (silently if switch in winpm-silent.lst)
echo        %~nx0 -type msi -list adob
echo              show all "adob"-Packages in msi format
echo        %~nx0 -type msi -install adob
echo              (automatic) silent instal first "adob"-Packages in msi format
goto :eof

:list
if "%everything%" == "1" echo *** Everything Mode Experimental *** && %~dp0es.exe -full-path-and-name %packpath%\ *%1*.%type% -sort dm
REM if "%everything%" == "0" for /R %packpath% %%i in (*%1*.%type%) do @echo %%~dpnxi
if "%everything%" == "0" for /F "delims=" %%i in ('dir %packpath%\*%1*.%type% /S /B /O-D') do @echo %%~dpnxi
exit /b

:findpkg:
set fl=
for /F %%i in ('findstr /I /R %1 "%instlist%"') do (
if "%fl%"=="" set fl=%%~dpnxi
)
Echo found: %fl%
for /F "delims=; tokens=1-2" %%x in (%~dp0winpm-silent.lst) do @echo %fl%|findstr /I /R %%x>NUL && set fl=%%~dpnxi (*Silent)
exit /b

:updatelist
for /F %%a in ('type r:\tst.lst^|find /C "."') do set from=%%a
dir "%packpath%" /S /B /O-D|findstr /I /C:".exe" /C:".msi" /C:".winpm">"%instlist%"
for /F %%b in ('type r:\tst.lst^|find /C "."') do set to=%%b
echo ...updated from %from% to %to%
exit /b

:winpm
if /i "%1"=="l" 7z e -p%winpmpass% -so %2 _install_
::URL
if /i "%1"=="-u" for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %2 _install_') do @if /I "%%i"=="u" start "%%j"
::SILENT install
if /i "%1"=="-s" for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %2 _install_') do @if /I "%%i"=="s" start /WAIT "" %%j
::SILENT uninstall
if /i "%1"=="-x" for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %2 _install_') do @if /I "%%i"=="x" start /WAIT "" %%j
::Download from vendor
if /i "%1"=="-d" for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %2 _install_') do @if /I "%%i"=="d" wget --content-disposition "%%j"
::Product Title
if /i "%1"=="-p" for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %2 _install_') do @if /I "%%i"=="p" echo %%j
exit /b


:unpackWinPM
7z X -mhe -p%winpmpass% "%1.WinPM"
exit /b

:makeWinPM
7z a -r -mx9 -mqs -p%winpmpass% -mhe "%1.WinPM" .
exit /b

:pull
xcopy /Y %1
exit /b

:push
REM xcopy /Y %1 "%packpath%\"
robocopy %~dp1 "%packpath%" %~nx1 /njh /njs /ndl /nc /ns
exit /b

:rename
set f=%1
for /F "tokens=2*" %%i in ('7z l %f% ^| find /I "productversion"') do @echo %f%|find /I "%%i">NUL || echo Renaming... %f% to %f:~0,-4%_v%%i%f:~-4% && move %f% %f:~0,-4%_v%%i%f:~-4%&exit /b
exit /b

:install
set sswitch=
echo Type: %type% 
echo file: %~n1
for /F "delims=; tokens=1-2" %%x in (%silentlist%) do @echo %~nx1|findstr /I /R %%x >NUL && set "sswitch=%%y "
if not "%sswitch%x" == "x" echo Silentswitch: %sswitch%
REM echo Install: %1 %sswitch%%2 %3 %4 %5 %6 %7 %8

if /i "%type%" == "7z" start /wait "" 7z.exe x %1 &exit /b
if /i "%type%" == "WinPM" start /wait "" 7z.exe -y -p%winpmpass% x -xr!_install_ -o%temp%\%~n1\ %1 && CD /D "%temp%\%~n1" && for /F "delims=# tokens=1-2*" %%i in ('7z e -p%winpmpass% -so %1 _install_') do (if /I "%%i"=="s" echo %%j & start /WAIT "" %%j) &cd /D %~dp0
if /i "%type%" == "exe" start /WAIT "" %1 %sswitch%%2 %3 %4 %5 %6 %7 %8& exit /b
if /i "%type%" == "msi" start /WAIT "" msiexec.exe /I"%1" /qn /norestart &exit /b