-- TLV格式固件包生成器
-- 用于生成符合规范的测试固件包

-- TLV辅助函数
local function write_uint16_be(value)
    -- 大端序写入16位整数
    return string.char(math.floor(value / 256), value % 256)
end

local function write_uint8(value)
    -- 写入8位整数
    return string.char(value)
end

local function create_tlv(tag, data)
    -- 创建TLV结构: TAG(1字节) + LENGTH(2字节大端序) + VALUE
    local length = #data
    return write_uint8(tag) .. write_uint16_be(length) .. data
end

local function generate_random_data(size)
    -- 生成指定大小的随机数据
    local data = {}
    math.randomseed(os.time())
    for i = 1, size do
        table.insert(data, string.char(math.random(0, 255)))
    end
    return table.concat(data)
end

local function generate_pattern_data(size, pattern)
    -- 生成指定大小的模式数据
    local data = {}
    for i = 1, size do
        table.insert(data, string.char((i - 1 + pattern) % 256))
    end
    return table.concat(data)
end

-- 生成固件包的函数
local function generate_firmware_package(group_length, firmware_size, mac_pattern, firmware_pattern, description)
    print("生成固件包: " .. description)
    print("  分组长度: " .. group_length .. " 字节")
    print("  固件大小: " .. firmware_size .. " 字节")
    
    -- 验证固件大小是分组长度的整数倍
    if firmware_size % group_length ~= 0 then
        error("固件大小必须是分组长度的整数倍")
    end
    
    local groups_count = firmware_size / group_length
    print("  分组数量: " .. groups_count)
    
    -- 创建内部TLV结构
    local inner_tlvs = {}
    
    -- TAG=0x57: 分组长度 (2字节大端序)
    local group_length_data = write_uint16_be(group_length)
    table.insert(inner_tlvs, create_tlv(0x57, group_length_data))
    
    -- TAG=0x58: 固件包MAC (16字节)
    local mac_data = ""
    for i = 1, 16 do
        mac_data = mac_data .. string.char((i - 1 + mac_pattern) % 256)
    end
    table.insert(inner_tlvs, create_tlv(0x58, mac_data))
    
    -- TAG=0x59: 密文固件包
    local firmware_data = generate_pattern_data(firmware_size, firmware_pattern)
    table.insert(inner_tlvs, create_tlv(0x59, firmware_data))
    
    -- 组合内部TLV数据
    local inner_data = table.concat(inner_tlvs)
    
    -- 创建外部TLV (TAG=0x71)
    local firmware_package = create_tlv(0x71, inner_data)
    
    print("  外部TLV总长度: " .. #firmware_package .. " 字节")
    print("  内部数据长度: " .. #inner_data .. " 字节")
    
    return firmware_package
end

-- 保存文件的函数
local function save_firmware_file(filename, data, description)
    local file_path = filename
    local file = io.open(file_path, "wb")
    if not file then
        error("无法创建文件: " .. file_path)
    end
    
    file:write(data)
    file:close()
    
    print("✓ 已保存: " .. filename .. " (" .. #data .. " 字节)")
    print("  描述: " .. description)
    print("")
end

-- 主生成函数
local function generate_test_files()
    print(string.rep("=", 60))
    print("TLV格式固件包生成器")
    print(string.rep("=", 60))
    print("")
    
    -- 测试文件1: 小型固件包 (512字节分组, 2KB固件)
    local firmware1 = generate_firmware_package(
        512,    -- 分组长度
        2048,   -- 固件大小 (4个分组)
        0x10,   -- MAC模式
        0x20,   -- 固件数据模式
        "小型固件包 - 512字节分组"
    )
    save_firmware_file("test_firmware_small.bin", firmware1, "小型测试固件包，512字节分组，2KB总大小")
    
    -- 测试文件2: 中型固件包 (1024字节分组, 8KB固件)
    local firmware2 = generate_firmware_package(
        1024,   -- 分组长度
        8192,   -- 固件大小 (8个分组)
        0x30,   -- MAC模式
        0x40,   -- 固件数据模式
        "中型固件包 - 1024字节分组"
    )
    save_firmware_file("test_firmware_medium.bin", firmware2, "中型测试固件包，1024字节分组，8KB总大小")
    
    -- 测试文件3: 大型固件包 (2048字节分组, 16KB固件)
    local firmware3 = generate_firmware_package(
        2048,   -- 分组长度
        16384,  -- 固件大小 (8个分组)
        0x50,   -- MAC模式
        0x60,   -- 固件数据模式
        "大型固件包 - 2048字节分组"
    )
    save_firmware_file("test_firmware_large.bin", firmware3, "大型测试固件包，2048字节分组，16KB总大小")
    
    -- 测试文件4: 特殊分组大小 (256字节分组, 1KB固件)
    local firmware4 = generate_firmware_package(
        256,    -- 分组长度
        1024,   -- 固件大小 (4个分组)
        0x70,   -- MAC模式
        0x80,   -- 固件数据模式
        "特殊固件包 - 256字节分组"
    )
    save_firmware_file("test_firmware_special.bin", firmware4, "特殊测试固件包，256字节分组，1KB总大小")
    
    -- 测试文件5: 单分组固件包 (4096字节分组, 4KB固件)
    local firmware5 = generate_firmware_package(
        4096,   -- 分组长度
        4096,   -- 固件大小 (1个分组)
        0x90,   -- MAC模式
        0xA0,   -- 固件数据模式
        "单分组固件包 - 4096字节分组"
    )
    save_firmware_file("test_firmware_single.bin", firmware5, "单分组测试固件包，4096字节分组，4KB总大小")
    
    print(string.rep("=", 60))
    print("生成完成！")
    print("共生成5个测试固件包文件")
    print(string.rep("=", 60))
end

-- 生成详细信息文件
local function generate_info_file()
    local info_content = [[TLV格式测试固件包说明
========================

本目录包含5个符合TLV格式规范的测试固件包文件：

1. test_firmware_small.bin
   - 分组长度: 512字节
   - 固件大小: 2048字节 (2KB)
   - 分组数量: 4个
   - MAC模式: 0x10开始的递增序列
   - 固件数据: 0x20开始的递增序列

2. test_firmware_medium.bin
   - 分组长度: 1024字节
   - 固件大小: 8192字节 (8KB)
   - 分组数量: 8个
   - MAC模式: 0x30开始的递增序列
   - 固件数据: 0x40开始的递增序列

3. test_firmware_large.bin
   - 分组长度: 2048字节
   - 固件大小: 16384字节 (16KB)
   - 分组数量: 8个
   - MAC模式: 0x50开始的递增序列
   - 固件数据: 0x60开始的递增序列

4. test_firmware_special.bin
   - 分组长度: 256字节
   - 固件大小: 1024字节 (1KB)
   - 分组数量: 4个
   - MAC模式: 0x70开始的递增序列
   - 固件数据: 0x80开始的递增序列

5. test_firmware_single.bin
   - 分组长度: 4096字节
   - 固件大小: 4096字节 (4KB)
   - 分组数量: 1个
   - MAC模式: 0x90开始的递增序列
   - 固件数据: 0xA0开始的递增序列

TLV结构说明:
============

外层TLV:
- TAG: 0x71 (固件包标识)
- LENGTH: 2字节大端序，表示内部数据长度
- VALUE: 内部TLV结构

内层TLV结构:
1. TAG=0x57: 分组长度
   - LENGTH: 0x0002 (2字节)
   - VALUE: 2字节大端序整数，表示分组长度

2. TAG=0x58: 固件包MAC
   - LENGTH: 0x0010 (16字节)
   - VALUE: 16字节MAC值

3. TAG=0x59: 密文固件包
   - LENGTH: 固件包实际长度
   - VALUE: 固件包数据，长度必须是分组长度的整数倍

使用方法:
=========

这些文件可以用于测试TLV解析功能，验证：
1. 外层TAG=0x71的识别和解析
2. 内层TLV结构的正确解析
3. 分组长度的提取和验证
4. MAC值的提取
5. 固件包的分组处理

每个文件都严格按照TLV格式规范生成，可以直接用于测试脚本验证。
]]

    local info_file = io.open("test_firmware_info.txt", "w")
    if info_file then
        info_file:write(info_content)
        info_file:close()
        print("✓ 已生成说明文件: test_firmware_info.txt")
    end
end

-- 执行生成
generate_test_files()
generate_info_file()