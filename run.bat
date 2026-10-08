@echo off
chcp 65001 >nul
title Hoá iOS Cheat API Server
cd /d "%~dp0"

echo ========================================================
echo        HOÁ IOS CHEAT API SERVER - PORT 2007
echo ========================================================
echo.

where py >nul 2>nul
if %errorlevel% equ 0 (
    set PYTHON_CMD=py
) else (
    where python >nul 2>nul
    if %errorlevel% equ 0 (
        set PYTHON_CMD=python
    ) else (
        echo [LỖI] Không tìm thấy Python! Vui lòng cài đặt Python trên máy.
        echo Link tải: https://www.python.org/downloads/
        echo.
        pause
        exit /b 1
    )
)

echo [1/3] Kiểm tra thư viện Flask...
%PYTHON_CMD% -c "import flask" >nul 2>nul
if %errorlevel% neq 0 (
    echo [2/3] Đang cài đặt thư viện Flask...
    %PYTHON_CMD% -m pip install flask
)

echo [3/3] Đang khởi chạy API Server...
echo.
echo ========================================================
echo   Server API đang chạy tại: http://localhost:2007
echo   Admin Dashboard:          http://localhost:2007/admin
echo   Mật khẩu Admin:           nxt2007
echo   Nhấn Ctrl + C để dừng Server
echo ========================================================
echo.

:: Tự động mở trình duyệt sau 2 giây
start "" cmd /c "timeout /t 2 /nobreak >nul && start http://localhost:2007"

if exist "api\app.py" (
    %PYTHON_CMD% api\app.py
) else if exist "app.py" (
    %PYTHON_CMD% app.py
) else (
    echo [LỖI] Không tìm thấy file app.py!
    pause
    exit /b 1
)

if %errorlevel% neq 0 (
    echo.
    echo [CẢNH BÁO] Server đã dừng hoặc gặp sự cố.
    pause
)
