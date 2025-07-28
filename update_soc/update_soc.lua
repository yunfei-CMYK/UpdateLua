#!/usr/bin/env lua
-- Linux驱动和软件升级工具
-- 功能：从tar包中提取文件并替换系统中的驱动(.ko)和软件文件(.lua, .so)

local os = require("os")
local io = require("io")
local string = require("string")
local table = require("table")

-- 配置参数
local CONFIG = {
    upgrade_pkg = "/data/upgrade/upgrade.tar",        -- 升级包路径
    extract_dir = "/data/upgrade/temp/",             -- 临时解压目录
    backup_dir = "/data/upgrade/backup/",            -- 备份目录
    ko_target_dir = "/lib/modules/$(uname -r)/extra/", -- 内核模块目标目录
    lua_target_dir = "/usr/local/share/lua/5.1/",    -- Lua脚本目标目录
    so_target_dir = "/usr/local/lib/lua/5.1/",       -- 共享库目标目录
    log_file = "/var/log/upgrade.log",               -- 日志文件
}

-- 日志函数
local function log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_msg = string.format("[%s] %s\n", timestamp, message)
    
    -- 输出到控制台
    io.write(log_msg)
    
    -- 写入日志文件
    local file = io.open(CONFIG.log_file, "a")
    if file then
        file:write(log_msg)
        file:close()
    end
end

-- 执行系统命令并返回结果
local function execute(command)
    log("执行命令: " .. command)
    local handle = io.popen(command .. " 2>&1")
    local result = handle:read("*a")
    local exit_code = {handle:close()}
    return result, exit_code[3]
end

-- 创建目录(如果不存在)
local function create_directory(path)
    if not os.execute("test -d " .. path) then
        log("创建目录: " .. path)
        local result, code = execute("mkdir -p " .. path)
        if code ~= 0 then
            log("错误: 创建目录失败 - " .. result)
            return false
        end
    end
    return true
end

-- 备份文件
local function backup_file(original_path, backup_path)
    log("备份文件: " .. original_path .. " 到 " .. backup_path)
    local result, code = execute("cp -f " .. original_path .. " " .. backup_path)
    if code ~= 0 then
        log("错误: 备份文件失败 - " .. result)
        return false
    end
    return true
end

-- 替换文件
local function replace_file(source_path, target_path)
    log("替换文件: " .. source_path .. " 到 " .. target_path)
    local result, code = execute("cp -f " .. source_path .. " " .. target_path)
    if code ~= 0 then
        log("错误: 替换文件失败 - " .. result)
        return false
    end
    return true
end

-- 加载内核模块
local function load_kernel_module(module_name)
    log("加载内核模块: " .. module_name)
    local result, code = execute("modprobe " .. module_name)
    if code ~= 0 then
        log("错误: 加载内核模块失败 - " .. result)
        return false
    end
    return true
end

-- 卸载内核模块
local function unload_kernel_module(module_name)
    log("卸载内核模块: " .. module_name)
    local result, code = execute("rmmod " .. module_name)
    if code ~= 0 then
        -- 可能模块未加载，这不一定是错误
        log("警告: 卸载内核模块可能失败 - " .. result)
    end
    return true
end

-- 检查文件是否存在
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- 获取文件扩展名
local function get_file_extension(filename)
    return filename:match("%.([^%.]+)$")
end

-- 获取不带扩展名的文件名
local function get_filename_without_extension(filename)
    local name = filename:match("(.+)%.[^%.]+$")
    return name or filename
end

-- 主升级函数
local function perform_upgrade()
    log("===== 开始升级 =====")
    
    -- 检查升级包是否存在
    if not file_exists(CONFIG.upgrade_pkg) then
        log("错误: 升级包不存在 - " .. CONFIG.upgrade_pkg)
        return false
    end
    
    -- 创建必要的目录
    if not create_directory(CONFIG.extract_dir) then return false end
    if not create_directory(CONFIG.backup_dir) then return false end
    
    -- 解压升级包
    log("解压升级包: " .. CONFIG.upgrade_pkg)
    local result, code = execute("tar -xf " .. CONFIG.upgrade_pkg .. " -C " .. CONFIG.extract_dir)
    if code ~= 0 then
        log("错误: 解压升级包失败 - " .. result)
        return false
    end
    
    -- 获取解压后的文件列表
    local file_list = {}
    result, code = execute("find " .. CONFIG.extract_dir .. " -type f")
    if code ~= 0 then
        log("错误: 获取文件列表失败 - " .. result)
        return false
    end
    
    -- 处理文件列表
    for file_path in result:gmatch("[^\r\n]+") do
        local relative_path = file_path:sub(#CONFIG.extract_dir + 1)
        local file_ext = get_file_extension(relative_path)
        local file_name = file_path:match(".*/(.*)") or relative_path
        
        -- 根据文件类型确定目标目录
        local target_dir = ""
        if file_ext == "ko" then
            target_dir = CONFIG.ko_target_dir
        elseif file_ext == "lua" then
            target_dir = CONFIG.lua_target_dir
        elseif file_ext == "so" then
            target_dir = CONFIG.so_target_dir
        else
            log("跳过未知类型文件: " .. relative_path)
            goto continue
        end
        
        -- 展开变量(如$(uname -r))
        target_dir = target_dir:gsub("%$%((.-)%)", function(cmd)
            local handle = io.popen(cmd)
            local result = handle:read("*a"):gsub("%s+", "")
            handle:close()
            return result
        end)
        
        -- 确保目标目录存在
        if not create_directory(target_dir) then
            goto continue
        end
        
        local target_path = target_dir .. file_name
        local backup_path = CONFIG.backup_dir .. file_name
        
        -- 备份原文件
        if file_exists(target_path) then
            if not backup_file(target_path, backup_path) then
                log("警告: 备份失败，跳过文件: " .. relative_path)
                goto continue
            end
        end
        
        -- 替换文件
        if not replace_file(file_path, target_path) then
            log("错误: 替换文件失败，尝试恢复备份: " .. relative_path)
            if file_exists(backup_path) then
                replace_file(backup_path, target_path)
            end
            goto continue
        end
        
        -- 如果是内核模块，重新加载
        if file_ext == "ko" then
            local module_name = get_filename_without_extension(file_name)
            
            -- 卸载旧模块
            unload_kernel_module(module_name)
            
            -- 加载新模块
            if not load_kernel_module(module_name) then
                log("错误: 加载新内核模块失败，尝试恢复旧版本")
                if file_exists(backup_path) then
                    replace_file(backup_path, target_path)
                    load_kernel_module(module_name)
                end
            end
        end
        
        ::continue::
    end
    
    -- 更新动态链接库缓存(如果有.so文件)
    execute("ldconfig")
    
    log("===== 升级完成 =====")
    return true
end

-- 执行升级
local success = perform_upgrade()

-- 根据结果返回退出码
os.exit(success and 0 or 1)    