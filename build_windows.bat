@echo off
:: build_windows.bat — Compile RobotariisSessions pour Windows
:: Lance depuis le dossier robotariis_sessions\

echo 🤖 Build RobotariisSessions — Windows
echo ======================================

:: Vérifier Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python requis. Installe depuis https://python.org
    echo    Coche "Add Python to PATH" pendant l'installation.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do echo ✓ %%i

:: Installer dépendances
echo → Installation Flask + PyInstaller...
python -m pip install flask pyinstaller -q
echo ✓ Dépendances OK

:: Nettoyer les builds précédents
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
del /q *.spec 2>nul

:: Compiler
echo → Compilation en cours...
pyinstaller ^
    --onefile ^
    --name "RobotariisSessions" ^
    --add-data "templates;templates" ^
    --add-data "static;static" ^
    --hidden-import flask ^
    --hidden-import jinja2 ^
    --hidden-import werkzeug ^
    --hidden-import sqlite3 ^
    app.py

if exist dist\RobotariisSessions.exe (
    echo.
    echo ✅ Binaire créé : dist\RobotariisSessions.exe
    echo.
    echo → Double-clic sur dist\RobotariisSessions.exe pour lancer
    echo → Puis ouvrir http://localhost:5000
) else (
    echo ❌ Échec de la compilation
    pause
    exit /b 1
)

:: Nettoyer
rmdir /s /q build
del /q *.spec 2>nul
echo ✓ Nettoyage OK

pause
