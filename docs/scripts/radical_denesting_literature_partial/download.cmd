@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel% equ 0 (
    py -3 fetch_literature.py %*
) else (
    python fetch_literature.py %*
)
echo.
echo Finished. See index.html and download_state.json for successes and failures.
pause
