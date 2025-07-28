-- 公钥密码学演示脚本
-- 支持RSA、ECC、SM2等多种密码算法的密钥生成、加密解密、数字签名等操作

local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
end

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

local pkey = crypto.pkey

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
-- 新版密钥生成函数
local function generate(fmt, param1, param2)
	print('-----新版密钥生成(', fmt, param1, param2, ')-----')
	local pri = assert(pkey.generate(fmt, param1, param2))
	local pub = assert(pkey.new(pri:getString('PUBKEY/'), 'PUBKEY/'))
	print('私钥(PEM格式)=', crypto.hex(pri:getString())) --导出私钥
	print('公钥(原始格式)=', crypto.hex(pub:getString('RAWPUBKEY/'))) --导出公钥
	print('公钥(X509格式)=', crypto.hex(pub:getString('PUBKEY/'))) --导出X509公钥
	return pri,pub
end

-- RSA算法测试函数
local function test_rsa(rsa, rsa_pub)
	print('-----RSA算法测试-----')
	-- 基本加密解密测试
	local enc = assert(rsa_pub:encrypt('1122'))
	print('加密结果=', crypto.hex(enc))
	assert(rsa:decrypt(enc) == '1122')
	print('解密成功: 1122')
		
	-- OAEP填充模式加密测试
	local enc = (rsa_pub:encrypt('1122', crypto.RSA_PKCS1_OAEP_PADDING))
	if enc then
		print('OAEP加密结果=', crypto.hex(enc))
		assert(rsa:decrypt(enc, crypto.RSA_PKCS1_OAEP_PADDING) == '1122')
		print('OAEP解密成功: 1122')
	end
	
	-- 带标签的OAEP加密测试
	local enc = (rsa_pub:encrypt('1122', {padding="RSA_PKCS1_OAEP_PADDING",oaepHash="SHA1",oaepLabel="123"}))
	if enc then
		print('OAEP带标签加密结果=', crypto.hex(enc))
		assert(rsa:decrypt(enc, {padding="RSA_PKCS1_OAEP_PADDING",oaepHash="SHA1",oaepLabel="123"}) == '1122')
		print('OAEP带标签解密成功: 1122')
	end

	-- 数字签名测试
	local sig = assert(rsa:sign('1122'))
	print('签名结果=', crypto.hex(sig))
	assert(rsa_pub:verify('1122',sig))
	print('签名验证成功')
	--assert(rsa_pub:verify(sig) == '1122') --RSA特有，新版（0.4.2）不支持; 可用RSA_public_decrypt
	print('RSA公钥解密=', crypto.hex(rsa:RSA_public_decrypt(sig)))

	-- 带哈希的签名测试
	local sig = assert(rsa:sign(string.rep('1',20), {hash="SHA1"})) --带OID
	print('SHA1签名结果=', crypto.hex(sig))
	assert(rsa_pub:verify(string.rep('1',20), sig, {hash="SHA1"}))
	print('SHA1签名验证成功')
	print('RSA公钥解密=', crypto.hex(rsa:RSA_public_decrypt(sig)))

	-- PSS填充签名测试
	local options = {padding=crypto.RSA_PKCS1_PSS_PADDING, pssHash="SHA256"}
	local sig = assert(rsa:sign(string.rep('1122',8), options))
	print('PSS签名结果=', crypto.hex(sig))
	assert(rsa_pub:verify(string.rep('1122',8),sig, options))
	print('PSS签名验证成功')

	-- 摘要签名测试
	local sig = assert(rsa:digestSign('SHA1', '1122'))
	print('摘要签名结果=', crypto.hex(sig))
	print('RSA公钥解密=', crypto.hex(rsa:RSA_public_decrypt(sig)))
	assert(rsa_pub:digestVerify('SHA1', '1122',sig))
	print('摘要签名验证成功')

	-- RSA专用签名测试
	local sig = assert(rsa:RSA_sign("SHA1", string.rep('1122',5)))
	print('RSA专用签名结果=', crypto.hex(sig))
	assert(rsa_pub:RSA_verify("SHA1", string.rep('1122',5),sig))
	print('RSA专用签名验证成功')
	print('RSA公钥解密=', crypto.hex(rsa:RSA_public_decrypt(sig)))
end

-- ECC椭圆曲线算法测试函数
local function test_ec(ec, ec_pub)
	print('-----ECC椭圆曲线算法测试-----')
	-- 基本签名测试
	local sig = assert(ec:sign('1122'))
	print('ECC签名结果=', crypto.hex(sig))
	assert(ec_pub:verify('1122',sig))
	print('ECC签名验证成功')

	-- RS格式签名测试
	local sig = assert(ec:sign('1122', 'RS'))
	print('ECC签名结果(RS格式)=', crypto.hex(sig))
	assert(ec_pub:verify('1122',sig, 'RS'))
	print('ECC签名验证成功(RS格式)')
	
	-- 摘要签名测试
	local sig = assert(ec:digestSign('SHA1', '1122'))
	print('ECC摘要签名结果=', crypto.hex(sig))
	assert(ec_pub:digestVerify('SHA1', '1122',sig))
	print('ECC摘要签名验证成功')

	-- RS格式摘要签名测试
	local sig = assert(ec:digestSign('SHA1', '1122', 'RS'))
	print('ECC摘要签名结果(RS格式)=', crypto.hex(sig))
	assert(ec_pub:digestVerify('SHA1', '1122',sig, 'RS'))
	print('ECC摘要签名验证成功(RS格式)')
end

-- SM2算法测试函数(旧版API)
local function test_sm2_old(sm2, sm2_pub)
	print('-----SM2算法测试(旧版API)-----')
	-- SM2加密解密测试
	local enc = assert(sm2_pub:encrypt('1122', 0)) --crypto.FLAG_SM_FORMAT
	print('SM2加密结果(旧版)=', crypto.hex(enc))
	assert(sm2:decrypt(enc, 0) == '1122')
	print('SM2解密成功(旧版): 1122')

	-- SM2签名验证测试
	local sig = assert(sm2:sign('1122', 0)) --crypto.FLAG_SM_FORMAT
	print('SM2签名结果(旧版)=', crypto.hex(sig))
	assert(sm2_pub:verify('1122',sig, 0))
	print('SM2签名验证成功(旧版)')
end

-- SM2算法测试函数(新版API)
local function test_sm2(sm2, sm2_pub)
	print('-----SM2算法测试(新版API)-----')
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

-- ECDH密钥交换测试函数
local function test_ecdh()
	print('-----ECDH密钥交换测试-----')
	local priKey = string.decode('') --input  -- 输入私钥
	local otherPubKey = string.decode('') --input  -- 输入对方公钥
	local ec = assert(pkey.new(priKey))
	local secret = ec:computeKey(otherPubKey)
	print('共享密钥=', crypto.hex(secret))
end

-- JWT ES256算法测试函数
local function test_jwks_ES256()
	print('-----JWT ES256算法测试-----')
	-- Base64URL编码函数
	function jwt_encode(s)
		return crypto.encode.encode_block(s):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
	end
	local pri = assert(pkey.generate('EC/', "prime256v1"))
	local n = pri:getString('RAWPUBKEY/')
	local x,y = n:sub(2,33), n:sub(34, 65)
	print('生成JWT私钥和公钥坐标:')
	print(string.format('local token_prikey = "%s"', pri:getString('/PEM'):gsub("\n", "\\n")))
	print(string.format('local opts = {token_pubkey_x="%s", token_pubkey_y="%s"}', jwt_encode(x), jwt_encode(y)))
end

-- 主程序执行部分
print("\n=== 开始执行密码学算法测试 ===\n")

-- 如果支持旧版API，则执行旧版测试
if pkey.d2i then
	print(">>> 执行旧版API测试 <<<")
	test_rsa(generate_old('rsa', 1024, '\x01\x00\x01'))
	test_sm2(generate_old('sm2'))
	test_sm2_old(generate_old('sm2'))
	print("\n>>> 旧版API测试完成 <<<\n")
end

-- 执行新版API测试
print(">>> 执行新版API测试 <<<")
print("测试RSA-1024算法...")
test_rsa(generate('RSA/', 1024, '\x01\x00\x01'))

print("\n测试ECC-P192曲线...")
test_ec(generate('EC/', "prime192v1"))

print("\n测试ECC-P256曲线...")
test_ec(generate('EC/', "prime256v1"))

print("\n测试ECC-P384曲线...")
test_ec(generate('EC/', "secp384r1"))

print("\n测试SM2国密算法...")
test_sm2(generate('SM2/'))

print("\n测试JWT ES256算法...")
test_jwks_ES256()

print("\n=== 所有密码学算法测试完成 ===")
print("测试项目包括:")
print("- RSA加密解密、数字签名")
print("- ECC椭圆曲线数字签名")
print("- SM2国密算法加密解密、数字签名")
print("- JWT ES256算法密钥生成")
