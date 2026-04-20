@echo off
:: Journal de Sessions Robōtariis v0.3.1
:: Double-clic pour lancer

cd /d "%~dp0"

echo 🤖 Journal de Sessions Robotariis v0.3.1
echo ==========================================

:: Vérifier Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python non trouvé. Installe Python depuis https://python.org
    echo    Coche "Add Python to PATH" pendant l'installation.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do echo ✓ %%i trouvé

:: Installer Flask si absent
python -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo → Installation de Flask...
    python -m pip install flask -q
    echo ✓ Flask installé
) else (
    echo ✓ Flask présent
)

:: Ouvrir le navigateur après 2 secondes
start "" /b cmd /c "timeout /t 2 >nul && start http://localhost:5000"

echo.
echo → Lancement sur http://localhost:5000
echo → Ferme cette fenetre pour arreter
echo.

python app.py
pause
