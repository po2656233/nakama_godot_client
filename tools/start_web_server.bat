@echo off
chcp 65001 >nul
echo 🚀 启动Godot Web服务器...
echo.

REM 检查Python是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误：未找到Python
    echo 💡 请先安装Python 3.x
    echo 📥 下载地址：https://www.python.org/downloads/
    pause
    exit /b 1
)

REM 检查当前目录是否有index.html
if not exist "index.html" (
    echo ⚠️  警告：当前目录下没有找到index.html文件
    echo 💡 请确保在Godot Web导出的目录中运行此脚本
    echo.
)

REM 启动服务器
echo 🌐 正在启动服务器...
python web_server.py

pause 