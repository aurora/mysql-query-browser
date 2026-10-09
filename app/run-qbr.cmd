@echo off
rem Development launcher: puts the backend DLLs (and the MSYS2 libraries they need) on PATH.
rem Optional arguments are passed on, e.g.  run-qbr.cmd -h 127.0.0.1 -P 33306 -u root -p qbr-test
set "ROOT=%~dp0.."
set "PATH=C:\msys64\mingw64\bin;%ROOT%\backend\build;%PATH%"
start "" "%~dp0bin\qbr.exe" %*
