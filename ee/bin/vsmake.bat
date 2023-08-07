@echo off
setlocal EnableDelayedExpansion
set PATH=%~dp0;%PATH%
(%~dp0make 2>&1 %1 %2 %3 %4 %5 ^& ^>err.tmp call echo %%^^errorlevel%%) | %~dp0sed -e "s/\([^:]*\):\([0-9][0-9]*\)\(.*\)/\1 (\2) \3/"
set /p "leftErr=" <err.tmp
del err.tmp
exit /b %leftErr%