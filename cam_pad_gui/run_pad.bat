@echo off
cd /d "%~dp0\.."
py cam_pad_gui\pad_gui.py
if errorlevel 1 python cam_pad_gui\pad_gui.py
pause
