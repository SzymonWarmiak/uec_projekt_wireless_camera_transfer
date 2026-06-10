@echo off
cd /d "%~dp0\.."
py cam_control_gui\cam_control_gui.py
if errorlevel 1 python cam_control_gui\cam_control_gui.py
