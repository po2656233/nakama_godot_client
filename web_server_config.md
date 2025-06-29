# Web服务器配置说明

## 问题描述
Godot Web导出需要以下功能才能正常运行：
- Cross-Origin Isolation
- SharedArrayBuffer支持

## 解决方案

### 1. 使用自定义HTML模板
项目已包含自定义HTML模板 `web_template.html`，其中包含必要的HTTP头部。

### 2. Web服务器配置

#### Apache配置 (.htaccess)
```apache
# 启用Cross-Origin Isolation
Header always set Cross-Origin-Opener-Policy "same-origin"
Header always set Cross-Origin-Embedder-Policy "require-corp"

# 允许SharedArrayBuffer
Header always set Cross-Origin-Resource-Policy "same-origin"
```

#### Nginx配置
```nginx
location / {
    add_header Cross-Origin-Opener-Policy "same-origin";
    add_header Cross-Origin-Embedder-Policy "require-corp";
    add_header Cross-Origin-Resource-Policy "same-origin";
}
```

#### Node.js Express服务器
```javascript
app.use((req, res, next) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    next();
});
```

#### Python HTTP服务器
```python
import http.server
import socketserver

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        super().end_headers()

with socketserver.TCPServer(("", 8000), CustomHTTPRequestHandler) as httpd:
    print("服务器运行在 http://localhost:8000")
    httpd.serve_forever()
```

### 3. 本地测试
使用以下命令启动本地服务器：

```bash
# Python 3
python -m http.server 8000

# Node.js (需要安装http-server)
npx http-server -p 8000 --cors

# PHP
php -S localhost:8000
```

### 4. 验证配置
在浏览器控制台中检查：
```javascript
console.log('Cross-Origin Isolation:', crossOriginIsolated);
console.log('SharedArrayBuffer available:', typeof SharedArrayBuffer !== 'undefined');
```

## 注意事项
- 这些头部必须在HTTPS环境下才能正常工作
- 本地开发可以使用localhost
- 某些浏览器可能需要手动启用这些功能 