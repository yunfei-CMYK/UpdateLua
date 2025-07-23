#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1. GB2312/GBK → UTF-8
2. 把 UTF-8 内容保存到 js/ 目录下的同名 .js 文件
"""
import glob
import os

# 1. 源文件列表
txt_files = glob.glob('../example/javascript/*.txt')

# 2. 确保 js/ 目录存在
os.makedirs('js', exist_ok=True)

for txt_path in txt_files:
    # 3. 以 GB2312 或 GBK 读取
    try:
        with open(txt_path, 'r', encoding='gb2312') as f:
            content = f.read()
    except UnicodeDecodeError:
        with open(txt_path, 'r', encoding='gbk') as f:
            content = f.read()

    # 4. 生成目标 .js 路径
    base_name = os.path.splitext(os.path.basename(txt_path))[0]
    js_path = os.path.join('js', base_name + '.js')

    # 5. 以 UTF-8 写入 .js
    with open(js_path, 'w', encoding='utf-8') as f:
        # 【可选】若想把文本变成 JS 字符串常量，用下面两行替换 f.write(content)
        # escaped = content.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
        # f.write(f'const data = "{escaped}";\n')
        f.write(content)

print(f'已生成 {len(txt_files)} 个 .js 文件到 js/ 目录：')
for p in txt_files:
    print('  ', os.path.join('js', os.path.splitext(os.path.basename(p))[0] + '.js'))