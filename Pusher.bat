@echo off
setlocal enabledelayedexpansion
set /p Desc=Enter message:
cd .\
git add .
git commit -m "%Desc%"
git push
for /L %%1 in (1,1,5) do (
set "line="
for /L %%i in (1,1,11) do (
    set "line=!line!*"
    echo !line!
ping 127.0.0.1 -n 1 > nul
)
for /L %%i in (10,-1,1) do (
    set "line=!line:~0,-1!"
    echo !line!
ping 127.0.0.1 -n 1 > nul
)
)
echo Done!
timeout /t 2 /nobreak>nul
exit