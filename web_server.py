#!/usr/bin/env python3
"""
Godot Web导出本地测试服务器
支持Cross-Origin Isolation和SharedArrayBuffer
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

class GodotWebRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # 添加Cross-Origin Isolation头部
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        
        # 添加CORS头部（如果需要）
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        
        super().end_headers()
    
    def log_message(self, format, *args):
        # 自定义日志格式
        print(f"[{self.log_date_time_string()}] {format % args}")

def main():
    # 默认端口
    port = 8000
    
    # 检查命令行参数
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("错误：端口号必须是数字")
            sys.exit(1)
    
    # 检查当前目录
    current_dir = Path.cwd()
    print(f"服务器根目录: {current_dir}")
    
    # 检查是否存在index.html
    if not (current_dir / "index.html").exists():
        print("警告：当前目录下没有找到index.html文件")
        print("请确保在Godot Web导出的目录中运行此脚本")
    
    try:
        with socketserver.TCPServer(("", port), GodotWebRequestHandler) as httpd:
            print(f"🚀 Godot Web服务器启动成功！")
            print(f"📁 服务目录: {current_dir}")
            print(f"🌐 访问地址: http://localhost:{port}")
            print(f"🔒 Cross-Origin Isolation: 已启用")
            print(f"📦 SharedArrayBuffer: 已支持")
            print(f"⏹️  按 Ctrl+C 停止服务器")
            print("-" * 50)
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n🛑 服务器已停止")
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ 错误：端口 {port} 已被占用")
            print(f"💡 尝试使用其他端口：python web_server.py {port + 1}")
        else:
            print(f"❌ 错误：{e}")
    except Exception as e:
        print(f"❌ 未知错误：{e}")

if __name__ == "__main__":
    main() 