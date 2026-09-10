@echo off
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 goto use_python
py -3 download_all.py --include-candidates --zip radical_literature.zip
goto finished
:use_python
python download_all.py --include-candidates --zip radical_literature.zip
:finished
echo.
echo Check literature\download_manifest.json for exact successes and failures.
pause
