@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Thu tai - Danh gia nhan thuc NQ TW4
echo ============================================================
echo   THU TAI PHAN MEM DANH GIA NHAN THUC
echo   Chi chay khi trang quan tri dang o che do THU NGHIEM
echo ============================================================
echo.
where node >nul 2>nul
if errorlevel 1 (
  echo [LOI] May chua cai Node.js.
  echo Vao https://nodejs.org tai ban LTS, cai dat xong thi chay lai file nay.
  echo.
  pause
  exit /b
)
set SO=1000
set DONGTHOI=50
set /p SO=Tong so nguoi thi gia lap [mac dinh 1000]: 
set /p DONGTHOI=So nguoi bam cung luc [mac dinh 50]: 
echo.
node thu_tai.mjs --url https://nqqjxjitlrixribeyppl.supabase.co --key eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xcWp4aml0bHJpeHJpYmV5cHBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzMjQzOTksImV4cCI6MjEwODkwMDM5OX0.SCJcGfJiU8EnXuvI9mFC0AEA7pfNlCHZpdBqPjFzM90 --so %SO% --dong-thoi %DONGTHOI%
echo.
pause
