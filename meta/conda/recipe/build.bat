@echo off
setlocal enableextensions

rem Install the staged payload into the prefix, plus a launcher on PATH.
rem See build.sh for why the payload lives under libexec rather than being merged
rem into the prefix, and why USER_DATA is set outside the prefix.

set "PAYLOAD_DEST=%PREFIX%\libexec\scibmad"

rem rattler-build hands the script an extended-length source path, of the form
rem `\\?\D:\...`. That prefix switches off path normalisation, which means `..`
rem components are never resolved beneath it -- and roughly 500 of the Julia package
rem sources in the payload contain relative symlinks such as
rem `docs/src/index.md -> ../../README.md`. Following one under a `\\?\` root fails
rem with "ERROR 123 (0x0000007B) The filename, directory name, or volume label syntax
rem is incorrect", and robocopy then exits >= 8 and fails the build. The symlinked
rem files are the only ones affected, so the failure looks arbitrary until you notice
rem that every path in it is a link.
rem
rem Stripping the prefix gives an ordinary path, which normalises `..` as usual and
rem lets robocopy follow the links and copy the target contents. Copying them as
rem links instead (`/SL`) is the other option and is worse: creating a symlink on
rem Windows needs a privilege that an unprivileged user installing the package may
rem not have.
set "PAYLOAD_SRC=%SRC_DIR%"
if "%PAYLOAD_SRC:~0,4%"=="\\?\" set "PAYLOAD_SRC=%PAYLOAD_SRC:~4%"

mkdir "%PAYLOAD_DEST%" 2>nul
rem /E recurse including empty dirs, /NFL /NDL /NJH /NJS /NP quiet output. robocopy
rem reports success with exit codes below 8, which cmd would otherwise treat as
rem failure; anything at 8 or above is a real error.
rem /R:2 /W:2 is load bearing. robocopy defaults to /R:1000000 /W:30 -- a million
rem retries thirty seconds apart -- so a single file that fails with a *retryable*
rem error stops the build for the rest of the job's six hour budget rather than
rem failing it. That is what a copy step sitting at nearly two hours looked like.
rem /XJ keeps it from recursing into reparse points, which cannot loop in this tree
rem today but is free insurance against one appearing.
robocopy "%PAYLOAD_SRC%\payload" "%PAYLOAD_DEST%" /E /R:2 /W:2 /XJ /NFL /NDL /NJH /NJS /NP
if %ERRORLEVEL% GEQ 8 (
    echo ERROR: robocopy failed with exit code %ERRORLEVEL%
    exit /b 1
)

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

rem Exit explicitly. robocopy signals success with a non-zero code -- 1 means "files
rem were copied", which is the normal outcome here -- and rattler-build checks the
rem script's exit code, so letting robocopy's status fall through the end of the file
rem would fail the build on a copy that worked. Clearing `ERRORLEVEL` with `set` is
rem the usual suggestion and is wrong: it defines a real variable that shadows the
rem dynamic one, so every later `%ERRORLEVEL%` check reads the shadow instead.
endlocal
exit /b 0
