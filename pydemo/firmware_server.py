#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
固件下载HTTP服务器
专门用于提供固件包下载服务和MQTT测试
支持文件上传功能
"""

import http.server
import socketserver
import os
import json
import mimetypes
from urllib.parse import urlparse, parse_qs
import threading
import webbrowser
from datetime import datetime
import hashlib

class FirmwareHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """固件下载HTTP请求处理器"""
    
    def do_GET(self):
        """处理GET请求"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # 根路径显示固件下载页面
        if path == '/':
            self.send_firmware_page()
        # 固件下载接口
        elif path.startswith('/firmware/'):
            self.handle_firmware_download(path)
        # 固件列表API
        elif path == '/api/firmware/list':
            self.send_firmware_list()
        # 固件信息API
        elif path.startswith('/api/firmware/info/'):
            filename = path.split('/')[-1]
            self.send_firmware_info(filename)
        # 服务器状态
        elif path == '/api/status':
            self.send_status_response()
        # 默认处理静态文件
        else:
            super().do_GET()
    
    def do_POST(self):
        """处理POST请求 - 文件上传"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/api/upload':
            self.handle_file_upload()
        else:
            self.send_error(404, "Not Found")
    
    def handle_file_upload(self):
        """处理文件上传"""
        try:
            # 解析multipart/form-data
            content_type = self.headers.get('Content-Type', '')
            if not content_type.startswith('multipart/form-data'):
                self.send_error(400, "Content-Type must be multipart/form-data")
                return
            
            # 获取content length
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length == 0:
                self.send_error(400, "No file data received")
                return
            
            # 读取POST数据
            post_data = self.rfile.read(content_length)
            
            # 解析boundary
            boundary_match = content_type.split('boundary=')
            if len(boundary_match) < 2:
                self.send_error(400, "Invalid multipart boundary")
                return
            
            boundary = boundary_match[1].encode()
            uploaded_files = []
            
            # 分割multipart数据
            parts = post_data.split(b'--' + boundary)
            
            for part in parts:
                if len(part) < 10:  # 跳过太短的部分
                    continue
                    
                if b'Content-Disposition' not in part:
                    continue
                
                # 分离头部和数据
                try:
                    header_end = part.find(b'\r\n\r\n')
                    if header_end == -1:
                        continue
                    
                    headers = part[:header_end].decode('utf-8', errors='ignore')
                    file_data = part[header_end + 4:]
                    
                    # 移除结尾的\r\n
                    if file_data.endswith(b'\r\n'):
                        file_data = file_data[:-2]
                    
                    # 提取文件名
                    filename = None
                    if 'filename=' in headers:
                        filename_start = headers.find('filename=') + 9
                        filename_end = headers.find('\r\n', filename_start)
                        if filename_end == -1:
                            filename_end = headers.find(';', filename_start)
                        if filename_end == -1:
                            filename_end = len(headers)
                        
                        filename = headers[filename_start:filename_end].strip('"').strip("'")
                    
                    print(f"🔍 解析到文件: {filename}, 数据大小: {len(file_data)} bytes")
                    
                    if filename and len(file_data) > 0 and self.is_firmware_file(filename):
                        # 保存文件
                        file_path = os.path.join(os.getcwd(), filename)
                        with open(file_path, 'wb') as f:
                            f.write(file_data)
                        
                        # 计算文件信息
                        file_stat = os.stat(file_path)
                        md5_hash = hashlib.md5()
                        md5_hash.update(file_data)
                        
                        uploaded_files.append({
                            "filename": filename,
                            "size_bytes": file_stat.st_size,
                            "size_mb": file_stat.st_size / (1024 * 1024),
                            "md5": md5_hash.hexdigest(),
                            "download_url": f"http://localhost:{PORT}/firmware/{filename}"
                        })
                        
                        print(f"📤 文件上传成功: {filename} ({file_stat.st_size} bytes)")
                    elif filename:
                        print(f"❌ 文件被拒绝: {filename} (不是有效的固件文件或数据为空)")
                        
                except Exception as parse_error:
                    print(f"❌ 解析part失败: {str(parse_error)}")
                    continue
            
            if uploaded_files:
                response_data = {
                    "status": "success",
                    "message": f"成功上传 {len(uploaded_files)} 个文件",
                    "uploaded_files": uploaded_files
                }
            else:
                response_data = {
                    "status": "error",
                    "message": "没有有效的固件文件被上传。请确保文件格式为 .bin, .hex, .fw, .img, .rom"
                }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode('utf-8'))
            
        except Exception as e:
            print(f"❌ 文件上传失败: {str(e)}")
            import traceback
            traceback.print_exc()
            response_data = {
                "status": "error",
                "message": f"文件上传失败: {str(e)}"
            }
            self.send_response(500)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(json.dumps(response_data, ensure_ascii=False).encode('utf-8'))
    
    def send_firmware_page(self):
        """发送固件下载页面"""
        firmware_files = self.get_firmware_files()
        
        firmware_links = ""
        for firmware in firmware_files:
            firmware_links += f"""
            <div class="firmware-item">
                <h4>📦 {firmware['name']}</h4>
                <p><strong>大小:</strong> {firmware['size_mb']:.2f} MB</p>
                <p><strong>修改时间:</strong> {firmware['modified']}</p>
                <p><strong>MD5:</strong> <code>{firmware['md5']}</code></p>
                <div class="download-links">
                    <a href="/firmware/{firmware['name']}" class="download-btn" download>⬇️ 下载固件</a>
                    <a href="/api/firmware/info/{firmware['name']}" class="info-btn" target="_blank">ℹ️ 详细信息</a>
                    <button onclick="deleteFile('{firmware['name']}')" class="delete-btn">🗑️ 删除</button>
                </div>
                <div class="url-info">
                    <strong>MQTT测试URL:</strong> 
                    <code>http://localhost:{PORT}/firmware/{firmware['name']}</code>
                    <button onclick="copyToClipboard('http://localhost:{PORT}/firmware/{firmware['name']}')" class="copy-btn">📋 复制</button>
                </div>
            </div>
            """
        
        html_content = f"""
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>固件上传下载服务器</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; text-align: center; margin-bottom: 30px; }}
        .status {{ padding: 15px; background: #d4edda; border: 1px solid #c3e6cb; border-radius: 5px; margin: 20px 0; }}
        
        /* 上传区域样式 */
        .upload-section {{ 
            margin: 30px 0; padding: 25px; background: #f8f9fa; border: 2px dashed #007bff; 
            border-radius: 10px; text-align: center;
        }}
        .upload-section h3 {{ color: #007bff; margin-top: 0; }}
        .file-input-wrapper {{ position: relative; display: inline-block; margin: 15px 0; }}
        .file-input {{ 
            position: absolute; left: -9999px; opacity: 0; pointer-events: none;
        }}
        .file-input-label {{ 
            display: inline-block; padding: 12px 24px; background: #007bff; color: white; 
            border-radius: 5px; cursor: pointer; font-weight: bold; transition: background 0.3s;
        }}
        .file-input-label:hover {{ background: #0056b3; }}
        .upload-btn {{ 
            margin-left: 15px; padding: 12px 24px; background: #28a745; color: white; 
            border: none; border-radius: 5px; cursor: pointer; font-weight: bold;
        }}
        .upload-btn:hover {{ background: #218838; }}
        .upload-btn:disabled {{ background: #6c757d; cursor: not-allowed; }}
        .file-list {{ margin: 15px 0; text-align: left; }}
        .file-item {{ 
            padding: 8px 12px; margin: 5px 0; background: #e9ecef; border-radius: 5px; 
            display: flex; justify-content: space-between; align-items: center;
        }}
        .remove-file {{ 
            background: #dc3545; color: white; border: none; border-radius: 3px; 
            padding: 4px 8px; cursor: pointer; font-size: 12px;
        }}
        .upload-progress {{ 
            margin: 15px 0; padding: 10px; background: #fff3cd; border-radius: 5px; display: none;
        }}
        
        /* 固件列表样式 */
        .firmware-item {{ margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #007bff; }}
        .firmware-item h4 {{ margin-top: 0; color: #007bff; }}
        .download-links {{ margin: 15px 0; }}
        .download-btn, .info-btn, .delete-btn {{ 
            display: inline-block; margin: 5px 10px 5px 0; padding: 8px 16px; 
            text-decoration: none; border-radius: 5px; font-weight: bold; border: none; cursor: pointer;
        }}
        .download-btn {{ background: #28a745; color: white; }}
        .download-btn:hover {{ background: #218838; }}
        .info-btn {{ background: #17a2b8; color: white; }}
        .info-btn:hover {{ background: #138496; }}
        .delete-btn {{ background: #dc3545; color: white; }}
        .delete-btn:hover {{ background: #c82333; }}
        .url-info {{ 
            margin: 10px 0; padding: 10px; background: #e9ecef; border-radius: 5px; 
            font-family: monospace; font-size: 12px;
        }}
        .copy-btn {{ 
            margin-left: 10px; padding: 4px 8px; background: #6c757d; color: white; 
            border: none; border-radius: 3px; cursor: pointer; font-size: 11px;
        }}
        .copy-btn:hover {{ background: #5a6268; }}
        .mqtt-section {{ 
            margin: 30px 0; padding: 20px; background: #fff3cd; border: 1px solid #ffeaa7; 
            border-radius: 8px;
        }}
        .mqtt-section h3 {{ color: #856404; margin-top: 0; }}
        .code-block {{ 
            background: #f8f9fa; padding: 15px; border-radius: 5px; 
            font-family: monospace; font-size: 14px; margin: 10px 0;
            border-left: 4px solid #007bff;
        }}
        .no-firmware {{ 
            text-align: center; padding: 40px; color: #6c757d; 
            background: #f8f9fa; border-radius: 8px; margin: 20px 0;
        }}
        .notification {{ 
            position: fixed; top: 20px; right: 20px; padding: 15px 20px; 
            border-radius: 5px; color: white; font-weight: bold; z-index: 1000;
            display: none;
        }}
        .notification.success {{ background: #28a745; }}
        .notification.error {{ background: #dc3545; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 固件上传下载服务器</h1>
        
        <div class="status">
            <strong>🟢 服务器状态:</strong> 运行中<br>
            <strong>📍 服务地址:</strong> http://localhost:{PORT}<br>
            <strong>⏰ 启动时间:</strong> {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}<br>
            <strong>📁 固件目录:</strong> {os.getcwd()}
        </div>
        
        <!-- 文件上传区域 -->
        <div class="upload-section">
            <h3>📤 上传固件文件</h3>
            <p>支持的文件格式: .bin, .hex, .fw, .img, .rom</p>
            
            <div class="file-input-wrapper">
                <input type="file" id="fileInput" class="file-input" multiple accept=".bin,.hex,.fw,.img,.rom">
                <label for="fileInput" class="file-input-label">📁 选择文件</label>
            </div>
            <button id="uploadBtn" class="upload-btn" onclick="uploadFiles()" disabled>📤 上传文件</button>
            
            <div id="fileList" class="file-list"></div>
            <div id="uploadProgress" class="upload-progress"></div>
        </div>
        
        <div class="mqtt-section">
            <h3>📡 MQTT测试说明</h3>
            <p>1. 上传固件文件后，复制下方的固件URL</p>
            <p>2. 使用MQTTX客户端向固件主题发送包含下载URL的消息：</p>
            <div class="code-block">
{{<br>
&nbsp;&nbsp;"firmware_url": "http://localhost:{PORT}/firmware/your_firmware.bin",<br>
&nbsp;&nbsp;"version": "1.0.0",<br>
&nbsp;&nbsp;"description": "自定义固件包"<br>
}}
            </div>
            <p>3. test.lua会自动下载固件到luademo目录</p>
        </div>
        
        <h2>📦 可用固件列表</h2>
        {firmware_links if firmware_links else '<div class="no-firmware"><h3>📭 暂无固件文件</h3><p>请使用上方的上传功能添加固件文件</p></div>'}
        
        <div style="margin-top: 40px; padding: 20px; background: #e9ecef; border-radius: 8px;">
            <h3>🔧 API接口</h3>
            <ul>
                <li><a href="/api/firmware/list" target="_blank">📋 /api/firmware/list - 固件列表</a></li>
                <li><a href="/api/status" target="_blank">📊 /api/status - 服务器状态</a></li>
                <li><strong>📤 POST /api/upload - 文件上传接口</strong></li>
            </ul>
        </div>
    </div>
    
    <!-- 通知消息 -->
    <div id="notification" class="notification"></div>
    
    <script>
        let selectedFiles = [];
        
        // 文件选择处理
        document.getElementById('fileInput').addEventListener('change', function(e) {{
            const files = Array.from(e.target.files);
            selectedFiles = files.filter(file => {{
                const validExtensions = ['.bin', '.hex', '.fw', '.img', '.rom'];
                return validExtensions.some(ext => file.name.toLowerCase().endsWith(ext));
            }});
            
            updateFileList();
            document.getElementById('uploadBtn').disabled = selectedFiles.length === 0;
        }});
        
        // 更新文件列表显示
        function updateFileList() {{
            const fileListDiv = document.getElementById('fileList');
            if (selectedFiles.length === 0) {{
                fileListDiv.innerHTML = '';
                return;
            }}
            
            let html = '<h4>待上传文件:</h4>';
            selectedFiles.forEach((file, index) => {{
                html += `
                <div class="file-item">
                    <span>📄 ${{file.name}} (${{(file.size / 1024 / 1024).toFixed(2)}} MB)</span>
                    <button class="remove-file" onclick="removeFile(${{index}})">移除</button>
                </div>`;
            }});
            fileListDiv.innerHTML = html;
        }}
        
        // 移除文件
        function removeFile(index) {{
            selectedFiles.splice(index, 1);
            updateFileList();
            document.getElementById('uploadBtn').disabled = selectedFiles.length === 0;
        }}
        
        // 上传文件
        async function uploadFiles() {{
            if (selectedFiles.length === 0) return;
            
            const uploadBtn = document.getElementById('uploadBtn');
            const progressDiv = document.getElementById('uploadProgress');
            
            uploadBtn.disabled = true;
            uploadBtn.textContent = '⏳ 上传中...';
            progressDiv.style.display = 'block';
            progressDiv.innerHTML = '📤 正在上传文件，请稍候...';
            
            try {{
                const formData = new FormData();
                selectedFiles.forEach(file => {{
                    formData.append('files', file);
                }});
                
                const response = await fetch('/api/upload', {{
                    method: 'POST',
                    body: formData
                }});
                
                const result = await response.json();
                
                if (result.status === 'success') {{
                    showNotification(result.message, 'success');
                    // 清空文件选择
                    selectedFiles = [];
                    document.getElementById('fileInput').value = '';
                    updateFileList();
                    // 刷新页面显示新上传的文件
                    setTimeout(() => location.reload(), 1500);
                }} else {{
                    showNotification(result.message, 'error');
                }}
            }} catch (error) {{
                showNotification('上传失败: ' + error.message, 'error');
            }} finally {{
                uploadBtn.disabled = false;
                uploadBtn.textContent = '📤 上传文件';
                progressDiv.style.display = 'none';
            }}
        }}
        
        // 显示通知
        function showNotification(message, type) {{
            const notification = document.getElementById('notification');
            notification.textContent = message;
            notification.className = `notification ${{type}}`;
            notification.style.display = 'block';
            
            setTimeout(() => {{
                notification.style.display = 'none';
            }}, 3000);
        }}
        
        // 复制到剪贴板
        function copyToClipboard(text) {{
            navigator.clipboard.writeText(text).then(function() {{
                showNotification('URL已复制到剪贴板！', 'success');
            }}, function(err) {{
                showNotification('复制失败', 'error');
            }});
        }}
        
        // 删除文件
        async function deleteFile(filename) {{
            if (!confirm(`确定要删除固件文件 "${{filename}}" 吗？`)) {{
                return;
            }}
            
            try {{
                // 这里可以添加删除API调用
                showNotification('删除功能待实现', 'error');
            }} catch (error) {{
                showNotification('删除失败: ' + error.message, 'error');
            }}
        }}
    </script>
</body>
</html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html_content.encode('utf-8'))
    
    def handle_firmware_download(self, path):
        """处理固件下载请求"""
        filename = path.split('/')[-1]
        file_path = os.path.join(os.getcwd(), filename)
        
        if os.path.exists(file_path) and self.is_firmware_file(filename):
            # 记录下载日志
            print(f"📥 固件下载请求: {filename} - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            
            # 设置适当的MIME类型
            mime_type = 'application/octet-stream'
            self.send_response(200)
            self.send_header('Content-Type', mime_type)
            self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
            self.send_header('Content-Length', str(os.path.getsize(file_path)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            # 发送文件内容
            with open(file_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, f"固件文件 {filename} 不存在")
    
    def send_firmware_list(self):
        """发送固件列表API响应"""
        firmware_files = self.get_firmware_files()
        
        response_data = {
            "status": "success",
            "timestamp": datetime.now().isoformat(),
            "firmware_count": len(firmware_files),
            "firmware_list": firmware_files
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode('utf-8'))
    
    def send_firmware_info(self, filename):
        """发送特定固件信息"""
        file_path = os.path.join(os.getcwd(), filename)
        
        if os.path.exists(file_path) and self.is_firmware_file(filename):
            file_stat = os.stat(file_path)
            
            # 计算文件MD5
            md5_hash = hashlib.md5()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    md5_hash.update(chunk)
            
            firmware_info = {
                "status": "success",
                "firmware": {
                    "name": filename,
                    "size_bytes": file_stat.st_size,
                    "size_mb": file_stat.st_size / (1024 * 1024),
                    "modified": datetime.fromtimestamp(file_stat.st_mtime).isoformat(),
                    "md5": md5_hash.hexdigest(),
                    "download_url": f"http://localhost:{PORT}/firmware/{filename}"
                }
            }
        else:
            firmware_info = {
                "status": "error",
                "message": f"固件文件 {filename} 不存在"
            }
        
        self.send_response(200 if firmware_info["status"] == "success" else 404)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(firmware_info, ensure_ascii=False, indent=2).encode('utf-8'))
    
    def send_status_response(self):
        """发送服务器状态响应"""
        firmware_files = self.get_firmware_files()
        
        status_data = {
            "server_status": "running",
            "current_time": datetime.now().isoformat(),
            "server_info": {
                "type": "Firmware Download Server",
                "port": PORT,
                "firmware_directory": os.getcwd(),
                "firmware_count": len(firmware_files)
            }
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(status_data, ensure_ascii=False, indent=2).encode('utf-8'))
    
    def get_firmware_files(self):
        """获取当前目录下的固件文件列表"""
        firmware_files = []
        
        for filename in os.listdir('.'):
            if self.is_firmware_file(filename):
                file_path = os.path.join('.', filename)
                file_stat = os.stat(file_path)
                
                # 计算文件MD5
                md5_hash = hashlib.md5()
                with open(file_path, "rb") as f:
                    for chunk in iter(lambda: f.read(4096), b""):
                        md5_hash.update(chunk)
                
                firmware_files.append({
                    "name": filename,
                    "size_bytes": file_stat.st_size,
                    "size_mb": file_stat.st_size / (1024 * 1024),
                    "modified": datetime.fromtimestamp(file_stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
                    "md5": md5_hash.hexdigest()
                })
        
        return sorted(firmware_files, key=lambda x: x['modified'], reverse=True)
    
    def is_firmware_file(self, filename):
        """判断是否为固件文件"""
        firmware_extensions = ['.bin', '.hex', '.fw', '.img', '.rom']
        return any(filename.lower().endswith(ext) for ext in firmware_extensions)

def start_firmware_server(port=8000):
    """启动固件下载服务器"""
    global PORT
    PORT = port
    
    # 切换到脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # 创建服务器
    with socketserver.TCPServer(("", port), FirmwareHTTPRequestHandler) as httpd:
        print("=" * 60)
        print("🚀 固件下载服务器启动成功!")
        print("=" * 60)
        print(f"📍 服务器地址: http://localhost:{port}")
        print(f"📁 固件目录: {script_dir}")
        print(f"⏰ 启动时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 60)
        print("📋 可用链接:")
        print(f"   🏠 主页: http://localhost:{port}/")
        print(f"   📦 固件下载: http://localhost:{port}/firmware/[filename]")
        print(f"   📋 固件列表: http://localhost:{port}/api/firmware/list")
        print(f"   📊 服务状态: http://localhost:{port}/api/status")
        print("=" * 60)
        print("📡 MQTT测试消息格式:")
        print('   {"firmware_url": "http://localhost:8000/firmware/test.bin"}')
        print("=" * 60)
        print("按 Ctrl+C 停止服务器")
        print()
        
        # 自动打开浏览器
        def open_browser():
            webbrowser.open(f'http://localhost:{port}')
        
        timer = threading.Timer(1.0, open_browser)
        timer.start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 固件下载服务器已停止")

if __name__ == "__main__":
    start_firmware_server()