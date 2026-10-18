@echo off
REM setup_env.bat — assistente de configuração (.env do servidor) para Windows.
setlocal enabledelayedexpansion

echo === Business Hub — configuração do servidor ===
cd /d "%~dp0server"

set /p WA_TOKEN="1) Meta Access Token (comeca com 'EA'): "
echo %WA_TOKEN% | findstr /R "^EA[0-9A-Za-z][0-9A-Za-z]*$" >nul
if errorlevel 1 echo    Aviso: nao parece um token da Meta (esperado EAAB...).

set /p PHONE_ID="2) Phone Number ID (so numeros): "
echo %PHONE_ID% | findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 echo    Aviso: Phone Number ID costuma ser so numeros.

set /p SA="3) Caminho do sa.json do Firebase [.\sa.json]: "
if "%SA%"=="" set SA=.\sa.json

set /p VERIFY="4) Frase secreta do webhook (vazio = gerar): "
if "%VERIFY%"=="" (
  for /f %%i in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString('N').Substring(0,24)"') do set VERIFY=%%i
  echo    Gerada: !VERIFY!
)

(
echo # Gerado por setup_env.bat em %DATE% %TIME%
echo VERIFY_TOKEN=!VERIFY!
echo WA_TOKEN=!WA_TOKEN!
echo GRAPH_VERSION=v21.0
echo FIREBASE_SA=!SA!
echo PORT=3000
echo # PHONE_NUMBER_ID principal ^(referencia^): !PHONE_ID!
) > .env

echo.
echo .env criado em server\.env
echo Proximos passos: coloque o sa.json em server\, rode o servidor com
echo   npm install ^& npm start
echo e configure os Secrets do GitHub pela interface web (Settings ^> Secrets):
echo   KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS
endlocal
