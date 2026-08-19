@echo off
rem ------------------------------------------------------------------
rem  Tela Compartilhada - modo app (estilo Discord)
rem
rem  Abre a plataforma numa janela propria do Chrome, com perfil e
rem  configuracoes SEPARADAS do seu Chrome normal. A aceleracao de
rem  hardware fica ligada AQUI DENTRO (destrava o NVENC pro Turbo),
rem  e o seu Chrome do dia a dia nao muda nada.
rem ------------------------------------------------------------------

set CHROME="%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist %CHROME% set CHROME="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist %CHROME% set CHROME="%LocalAppData%\Google\Chrome\Application\chrome.exe"

if not exist %CHROME% (
  echo Nao achei o Chrome instalado. Instale o Chrome ou me avise.
  pause
  exit /b 1
)

start "" %CHROME% --user-data-dir="%LocalAppData%\TelaCompartilhada" --app=https://compartilhartela.netlify.app
