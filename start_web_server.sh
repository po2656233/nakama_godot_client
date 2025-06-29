#!/bin/bash

echo "🚀 启动Godot Web服务器..."
echo

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误：未找到Python3"
    echo "💡 请先安装Python 3.x"
    echo "📥 Ubuntu/Debian: sudo apt install python3"
    echo "📥 macOS: brew install python3"
    exit 1
fi

# 检查当前目录是否有index.html
if [ ! -f "index.html" ]; then
    echo "⚠️  警告：当前目录下没有找到index.html文件"
    echo "💡 请确保在Godot Web导出的目录中运行此脚本"
    echo
fi

# 启动服务器
echo "🌐 正在启动服务器..."
python3 web_server.py 