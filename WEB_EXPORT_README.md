# Godot Web导出解决方案

## 问题描述
Godot Web导出时出现以下错误：
```
The following features required to run Godot projects on the Web are missing:
Cross-Origin Isolation - Check that the web server configuration sends the correct headers.
SharedArrayBuffer - Check that the web server configuration sends the correct headers.
```

## 解决方案

### 1. 项目配置已更新
- ✅ 已添加自定义HTML模板 (`web_template.html`)
- ✅ 已更新导出配置 (`export_presets.cfg`)
- ✅ 包含必要的Cross-Origin Isolation头部

### 2. 导出步骤

1. **在Godot编辑器中导出Web版本**
   - 项目 → 导出
   - 选择"Web"预设
   - 点击"导出项目"
   - 选择导出目录（例如：`程序_打包/nndy/`）

2. **使用提供的服务器脚本**

#### Windows用户：
```bash
# 进入导出目录
cd 程序_打包/nndy/

# 运行批处理文件
start_web_server.bat
```

#### Linux/Mac用户：
```bash
# 进入导出目录
cd 程序_打包/nndy/

# 给脚本添加执行权限（Linux/Mac）
chmod +x start_web_server.sh

# 运行脚本
./start_web_server.sh
```

#### 手动启动（所有平台）：
```bash
# 进入导出目录
cd 程序_打包/nndy/

# 使用Python启动服务器
python web_server.py
# 或者
python3 web_server.py
```

### 3. 访问游戏
服务器启动后，在浏览器中访问：
```
http://localhost:8000
```

### 4. 验证配置
在浏览器控制台中检查：
```javascript
console.log('Cross-Origin Isolation:', crossOriginIsolated);
console.log('SharedArrayBuffer available:', typeof SharedArrayBuffer !== 'undefined');
```

应该显示：
```
Cross-Origin Isolation: true
SharedArrayBuffer available: true
```

## 文件说明

- `web_template.html` - 自定义HTML模板，包含必要的HTTP头部
- `web_server.py` - Python服务器脚本，自动添加Cross-Origin头部
- `start_web_server.bat` - Windows批处理文件
- `start_web_server.sh` - Linux/Mac Shell脚本
- `web_server_config.md` - 详细的服务器配置说明

## 生产环境部署

### Apache (.htaccess)
```apache
Header always set Cross-Origin-Opener-Policy "same-origin"
Header always set Cross-Origin-Embedder-Policy "require-corp"
Header always set Cross-Origin-Resource-Policy "same-origin"
```

### Nginx
```nginx
location / {
    add_header Cross-Origin-Opener-Policy "same-origin";
    add_header Cross-Origin-Embedder-Policy "require-corp";
    add_header Cross-Origin-Resource-Policy "same-origin";
}
```

## 注意事项

1. **HTTPS要求**：生产环境必须使用HTTPS
2. **本地测试**：localhost可以使用HTTP
3. **浏览器兼容性**：现代浏览器都支持这些功能
4. **性能影响**：Cross-Origin Isolation可能会影响某些第三方库

## 故障排除

### 如果仍然出现错误：
1. 确保在正确的目录中运行服务器脚本
2. 检查浏览器控制台是否有其他错误
3. 尝试使用不同的浏览器
4. 确保服务器脚本正在运行

### 常见问题：
- **端口被占用**：脚本会自动提示使用其他端口
- **Python未安装**：下载并安装Python 3.x
- **权限问题**：确保有读取导出文件的权限 