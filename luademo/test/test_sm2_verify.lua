require('ldconfig')('crypto')
local crypto = require('crypto')
local pkey = crypto.pkey

print("=== 公钥密码学演示程序 ===")
print("LuaCrypto 版本: " .. crypto._VERSION)
print("支持的算法: RSA、ECC、SM2")
print("")

-- API 函数说明 (已废弃的函数)
--Deprecated(generate)(type, key_len, [e]/[asn1_flag, nid])  -- 生成密钥对(旧版)
--Deprecated(d2i)(type, der, ispubkey, nid)                  -- DER格式导入(旧版)
--Deprecated(i2d)(obj, ispubkey, flags)                      -- DER格式导出(旧版)
-- flags: crypto.FLAG_PKCS1_PADDING/FLAG_SM_FORMAT/FLAG_OUTPUT_HEXSTRING

-- API 函数说明 (新版函数)
--new(payload, [fmt])                                        -- 从数据创建密钥对象
--generate(fmt, [key_bits/curve_name], [pubexp/nid])         -- 生成密钥对 fmt: RSA/,EC/,SM2/
--encrypt(obj,input,[options/Deprecated(flags)])             -- 加密操作
--decrypt(obj,input,[options/Deprecated(flags)])             -- 解密操作
--sign(obj,input,[options/Deprecated(flags)])                -- 数字签名
--verify(obj,input,sig,[options/Deprecated(flags)])          -- 签名验证
--digestSign(obj,hashName,input,[options])                   -- 摘要签名
--digestVerify(obj,hashName,input,sig,[options])             -- 摘要验证
--RSA_sign(obj,hashName,input)                               -- RSA专用签名
--RSA_verify(obj,hashName,input,sig)                         -- RSA专用验证
--print("crypto.pkey", crypto.meta_table("crypto.pkey"))

-- 选项参数说明:
--options(number): rsa padding                               -- RSA填充模式(数字)
--options(string): padding(P1363/RS/C1C2C3/C1C3C2)          -- 填充模式(字符串)
--options(table): {padding, saltLength, pssHash, oaepHash, oaepLabel}  -- 详细选项(表格)

print('-----算法标识符(NID)查询-----')
print("RSA加密算法标识:", crypto.nid("rsaEncryption"))
print("ECC公钥算法标识:", crypto.nid("id-ecPublicKey"))
print("SM2算法标识:", crypto.nid("SM2"))

-- 旧版密钥生成函数 (已废弃)
local function generate_old(type_, key_len, e_or_asn1_flag, nid)
	print('-----旧版密钥生成(', type_, key_len, e_or_asn1_flag, nid, ')-----')
	local pri = assert(pkey.generate(type_, key_len, e_or_asn1_flag, nid))
	local pub = assert(pkey.d2i(type_, pri:i2d('pubkey'), 'pubkey'))
	print('私钥(DER格式)=', crypto.hex(pri:i2d())) --导出私钥
	print('公钥(DER格式)=', crypto.hex(pub:i2d('pubkey'))) --导出公钥
	print('公钥(X509格式)=', crypto.hex(pub:i2d_PUBKEY())) --导出X509公钥
	--pub=assert(pkey.d2i_PUBKEY(type_, pub:i2d_PUBKEY()))
	return pri,pub
end

local function generate(fmt, param1, param2)
    print('-----新版密钥生成(', fmt, param1, param2, ')-----')
    local pri = assert(pkey.generate(fmt,param1, param2))
    local pub = assert(pkey.new(pri:getString('PUBKEY/'), 'PUBKEY/'))
    print('私钥(PEM格式)=', crypto.hex(pri:getString())) --导出私钥
	print('公钥(原始格式)=', crypto.hex(pub:getString('RAWPUBKEY/'))) --导出公钥
	print('公钥(X509格式)=', crypto.hex(pub:getString('PUBKEY/'))) --导出X509公钥
	return pri,pub
end

local function test_sm2_old(sm2,sm2_pub)
    print('-----SM2算法测试(旧版API)-----')

    --encrypt and decrypt
    local enc = assert(sm2_pub:encrypt('1122',0))
    print('SM2加密结果(旧版)=', crypto.hex(enc))
	assert(sm2:decrypt(enc, 0) == '1122')
	print('SM2解密成功(旧版): 1122')

    -- sign verify
    local sig = assert(sm2:sign('1122', 0)) --crypto.FLAG_SM_FORMAT
	print('SM2签名结果(旧版)=', crypto.hex(sig))
	assert(sm2_pub:verify('1122',sig, 0))
	print('SM2签名验证成功(旧版)')

end

local function test_sm2(sm2, sm2_pub)
    -- 基本加密解密测试
	local enc = assert(sm2_pub:encrypt('1122'))
	print('SM2加密结果=', crypto.hex(enc))
	print('SM2密文转换(d2s)=', crypto.hex(crypto.d2s_SM2Ciphertext(enc)))
	assert(sm2:decrypt(enc) == '1122')
	print('SM2解密成功: 1122')

    -- C1C2C3格式加密测试
	local enc = assert(sm2_pub:encrypt('1122', "C1C2C3"))
	print('SM2加密结果(C1C2C3)=', crypto.hex(enc))
	print('SM2密文转换(s2d)=', crypto.hex(crypto.s2d_SM2Ciphertext(enc)))
	assert(sm2:decrypt(enc, "C1C2C3") == '1122')
	print('SM2解密成功(C1C2C3): 1122')

	-- C1C3C2格式加密测试
	local enc = assert(sm2_pub:encrypt('1122', "C1C3C2"))
	print('SM2加密结果(C1C3C2)=', crypto.hex(enc))
	print('SM2密文转换(s2d)=', crypto.hex(crypto.s2d_SM2Ciphertext(enc, 0)))
	assert(sm2:decrypt(enc, "C1C3C2") == '1122')
	print('SM2解密成功(C1C3C2): 1122')

    -- 基本签名测试
	local sig = assert(sm2:sign('1122'))
	print('SM2签名结果=', crypto.hex(sig))
	print('SM2签名转换(d2s)=', crypto.hex(crypto.d2s_SM2Signature(sig)))
	assert(sm2_pub:verify('1122',sig))
	print('SM2签名验证成功')

	-- RS格式签名测试
	local sig = assert(sm2:sign('1122', "RS"))
	print('SM2签名结果(RS格式)=', crypto.hex(sig))
	print('SM2签名转换(s2d)=', crypto.hex(crypto.s2d_SM2Signature(sig)))
	assert(sm2_pub:verify('1122',sig, "RS"))
	print('SM2签名验证成功(RS格式)')

    -- SM3摘要签名测试
	local sig = assert(sm2:digestSign('SM3', '1122'))
	print('SM2摘要签名结果=', crypto.hex(sig))
	assert(sm2_pub:digestVerify('SM3', '1122',sig))
	print('SM2摘要签名验证成功')
	
	-- SM3摘要签名测试(RS格式)
	local sig = assert(sm2:digestSign('SM3', '1122', "RS"))
	print('SM2摘要签名结果(RS格式)=', crypto.hex(sig))
	assert(sm2_pub:digestVerify('SM3', '1122',sig, "RS"))
	print('SM2摘要签名验证成功(RS格式)')
end

-- 主程序执行部分
print("\n=== 开始执行密码学算法测试 ===\n")

if pkey.d2i then
	print(">>> 执行旧版API测试 <<<")
	test_sm2(generate_old('sm2'))
	test_sm2_old(generate_old('sm2'))
	print("\n>>> 旧版API测试完成 <<<\n")
end

-- 执行新版API测试
print(">>> 执行新版API测试 <<<")

print("\n测试SM2国密算法...")
test_sm2(generate('SM2/'))