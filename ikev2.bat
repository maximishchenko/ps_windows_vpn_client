echo off
chcp 1251 >nul

NET SESSION >nul 2>&1


IF %ERRORLEVEL% EQU 0 (
    powershell -executionpolicy bypass -File "%~dp0\setup.ps1" -ConfigPath config\ikev2.ini
) ELSE (
    echo ERROR!!! THIS SCRIPT MUST BE RUNNING ONLY AS ADMINISTRATOR!!!
)
pause