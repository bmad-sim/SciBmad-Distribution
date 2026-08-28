@echo off
setlocal enableextensions

rem Install the staged payload into the prefix, plus a launcher on PATH.
rem See build.sh for why the payload lives under libexec rather than being merged
rem into the prefix, and why USER_DATA is set outside the prefix.

set "PAYLOAD_DEST=%PREFIX%\libexec\scibmad"

mkdir "%PAYLOAD_DEST%" 2>nul
rem /E recurse including empty dirs, /NFL /NDL /NJH /NJS quiet output. robocopy exits
rem with codes below 8 on success, which cmd otherwise treats as failure.
robocopy "%SRC_DIR%\payload" "%PAYLOAD_DEST%" /E /NFL /NDL /NJH /NJS /NP
if %ERRORLEVEL% GEQ 8 exit /b 1
set "ERRORLEVEL="

mkdir "%PREFIX%\bin" 2>nul

rem Written with `echo` lines rather than a heredoc; cmd has no heredoc, and the
rem parentheses and redirects inside the batch body need escaping as ^( ^) ^> .
> "%PREFIX%\bin\scibmad.bat" echo @echo off
>>"%PREFIX%\bin\scibmad.bat" echo setlocal enableextensions
>>"%PREFIX%\bin\scibmad.bat" echo rem Launcher for the SciBmad distribution.
>>"%PREFIX%\bin\scibmad.bat" echo set "SCIBMAD_PREFIX=%%~dp0.."
>>"%PREFIX%\bin\scibmad.bat" echo if "%%USER_DATA%%"=="" set "USER_DATA=%%LOCALAPPDATA%%\scibmad"
>>"%PREFIX%\bin\scibmad.bat" echo if not exist "%%USER_DATA%%" mkdir "%%USER_DATA%%"
>>"%PREFIX%\bin\scibmad.bat" echo "%%SCIBMAD_PREFIX%%\libexec\scibmad\bin\julia.exe" %%*

endlocal
