@echo off
cd /d "%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 download_all.py %*
) else (
  python download_all.py %*
)
set RESULT=%ERRORLEVEL%
echo.
echo Review download_results.csv and SUMMARY.json for actual files and failures.
pause
exit /b %RESULT%
