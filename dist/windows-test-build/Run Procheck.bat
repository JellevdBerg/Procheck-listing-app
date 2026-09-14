@echo off
cd /d "%~dp0"
echo.
echo Starting Procheck at http://localhost:8765
echo Leave this window open while you use the app.
echo Open http://localhost:8765 in Edge or Chrome, then use the
echo install icon in the address bar (or menu ... ^> Apps ^> Install)
echo to add it as a real app with its own window and Start Menu entry.
echo.
echo Press Ctrl+C here to stop the server when you're done.
echo.
py -m http.server 8765 || python -m http.server 8765
pause
