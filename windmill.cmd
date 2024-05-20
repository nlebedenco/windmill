@echo off
setlocal

python %~dp0extras\python\%~n0.py %*
if %errorlevel% neq 0 exit /b %errorlevel%
