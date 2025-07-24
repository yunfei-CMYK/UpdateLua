local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
end

print("LuaCrypto version: " .. crypto._VERSION)
print("")

--Deprecated(generate)(type, key_len, [e]/[asn1_flag, nid])
--Deprecated(d2i)(type, der, ispubkey, nid)
--Deprecated(i2d)(obj, ispubkey, flags) flags: crypto.FLAG_PKCS1_PADDING/FLAG_SM_FORMAT/FLAG_OUTPUT_HEXSTRING
--new(payload, [fmt]) --fmt:PUBKEY/
--generate(fmt, [key_bits/curve_name], [pubexp/nid]) --fmt: RSA/,EC/,SM2/
--encrypt(obj,input,[options/Deprecated(flags)])
--decrypt(obj,input,[options/Deprecated(flags)])
--sign(obj,input,[options/Deprecated(flags)])
--verify(obj,input,sig,[options/Deprecated(flags)])
--digestSign(obj,hashName,input,[options])
--digestVerify(obj,hashName,input,sig,[options])
--RSA_sign(obj,hashName,input)
--RSA_verify(obj,hashName,input,sig)
--print("crypto.pkey", crypto.meta_table("crypto.pkey"))

--options(number): rsa padding
--options(string): padding(P1363/RS/C1C2C3/C1C3C2)
--options(table): {padding, saltLength, pssHash, oaepHash, oaepLabel}


print('-----nid-----')
print("rsaEncryption", crypto.nid("rsaEncryption"))
print("id-ecPublicKey", crypto.nid("id-ecPublicKey"))
print("SM2", crypto.nid("SM2"))

local pkey = crypto.pkey

local function generate_old(type_, key_len, e_or_asn1_flag, nid)
	print('-----generate_old(', type_, key_len, e_or_asn1_flag, nid, ')-----')
	local pri = assert(pkey.generate(type_, key_len, e_or_asn1_flag, nid))
	local pub = assert(pkey.d2i(type_, pri:i2d('pubkey'), 'pubkey'))
	print('priKey=', crypto.hex(pri:i2d())) --导出私钥
	print('pubKey=', crypto.hex(pub:i2d('pubkey'))) --导出公钥
	print('pubKey(x509)=', crypto.hex(pub:i2d_PUBKEY())) --导出X509公钥
	--pub=assert(pkey.d2i_PUBKEY(type_, pub:i2d_PUBKEY()))
	return pri,pub
end
local function generate(fmt, param1, param2)
	print('-----generate(', fmt, param1, param2, ')-----')
	local pri = assert(pkey.generate(fmt, param1, param2))
	local pub = assert(pkey.new(pri:getString('PUBKEY/'), 'PUBKEY/'))
	print('priKey=', crypto.hex(pri:getString())) --导出私钥
	print('pubKey=', crypto.hex(pub:getString('RAWPUBKEY/'))) --导出公钥
	print('pubKey(x509)=', crypto.hex(pub:getString('PUBKEY/'))) --导出X509公钥
	return pri,pub
end

local function test_rsa(rsa, rsa_pub)
	print('-----test_rsa-----')
	local enc = assert(rsa_pub:encrypt('1122'))
	print('enc=', crypto.hex(enc))
	assert(rsa:decrypt(enc) == '1122')
		
	local enc = (rsa_pub:encrypt('1122', crypto.RSA_PKCS1_OAEP_PADDING))
	if enc then
		print('enc(OAEP)=', crypto.hex(enc))
		assert(rsa:decrypt(enc, crypto.RSA_PKCS1_OAEP_PADDING) == '1122')
	end
	local enc = (rsa_pub:encrypt('1122', {padding="RSA_PKCS1_OAEP_PADDING",oaepHash="SHA1",oaepLabel="123"}))
	if enc then
		print('enc(OAEP,Label)=', crypto.hex(enc))
		assert(rsa:decrypt(enc, {padding="RSA_PKCS1_OAEP_PADDING",oaepHash="SHA1",oaepLabel="123"}) == '1122')
	end

	local sig = assert(rsa:sign('1122'))
	print('sig=', crypto.hex(sig))
	assert(rsa_pub:verify('1122',sig))
	--assert(rsa_pub:verify(sig) == '1122') --RSA特有，新版（0.4.2）不支持; 可用RSA_public_decrypt
	print('RSA_public_decrypt=', crypto.hex(rsa:RSA_public_decrypt(sig)))

	local sig = assert(rsa:sign(string.rep('1',20), {hash="SHA1"})) --带OID
	print('sig=', crypto.hex(sig))
	assert(rsa_pub:verify(string.rep('1',20), sig, {hash="SHA1"}))
	print('RSA_public_decrypt=', crypto.hex(rsa:RSA_public_decrypt(sig)))

	local options = {padding=crypto.RSA_PKCS1_PSS_PADDING, pssHash="SHA256"}
	local sig = assert(rsa:sign(string.rep('1122',8), options))
	print('sig(pss)=', crypto.hex(sig))
	assert(rsa_pub:verify(string.rep('1122',8),sig, options))

	local sig = assert(rsa:digestSign('SHA1', '1122'))
	print('dst_sig=', crypto.hex(sig))
	print('RSA_public_decrypt=', crypto.hex(rsa:RSA_public_decrypt(sig)))
	
	assert(rsa_pub:digestVerify('SHA1', '1122',sig))

	local sig = assert(rsa:RSA_sign("SHA1", string.rep('1122',5)))
	print('sig(oid)=', crypto.hex(sig))
	assert(rsa_pub:RSA_verify("SHA1", string.rep('1122',5),sig))
	print('RSA_public_decrypt=', crypto.hex(rsa:RSA_public_decrypt(sig)))
end

local function test_ec(ec, ec_pub)
	print('-----test_ec-----')
	local sig = assert(ec:sign('1122'))
	print('sig=', crypto.hex(sig))
	assert(ec_pub:verify('1122',sig))

	local sig = assert(ec:sign('1122', 'RS'))
	print('sig(RS)=', crypto.hex(sig))
	assert(ec_pub:verify('1122',sig, 'RS'))
	
	local sig = assert(ec:digestSign('SHA1', '1122'))
	print('dst_sig=', crypto.hex(sig))
	assert(ec_pub:digestVerify('SHA1', '1122',sig))

	local sig = assert(ec:digestSign('SHA1', '1122', 'RS'))
	print('dst_sig(RS)=', crypto.hex(sig))
	assert(ec_pub:digestVerify('SHA1', '1122',sig, 'RS'))
end

local function test_sm2_old(sm2, sm2_pub)
	print('-----test_sm2_old-----')
	local enc = assert(sm2_pub:encrypt('1122', 0)) --crypto.FLAG_SM_FORMAT
	print('enc(xydh)=', crypto.hex(enc))
	assert(sm2:decrypt(enc, 0) == '1122')

	local sig = assert(sm2:sign('1122', 0)) --crypto.FLAG_SM_FORMAT
	print('sig(rs)=', crypto.hex(sig))
	assert(sm2_pub:verify('1122',sig, 0))
end

local function test_sm2(sm2, sm2_pub)
	print('-----test_sm2-----')
	local enc = assert(sm2_pub:encrypt('1122'))
	print('enc=', crypto.hex(enc))
	print('enc(d2s)=', crypto.hex(crypto.d2s_SM2Ciphertext(enc)))
	assert(sm2:decrypt(enc) == '1122')

	local enc = assert(sm2_pub:encrypt('1122', "C1C2C3"))
	print('enc(C1C2C3)=', crypto.hex(enc))
	print('enc(s2d)=', crypto.hex(crypto.s2d_SM2Ciphertext(enc)))
	assert(sm2:decrypt(enc, "C1C2C3") == '1122')

	local enc = assert(sm2_pub:encrypt('1122', "C1C3C2"))
	print('enc(C1C3C2)=', crypto.hex(enc))
	print('enc(s2d)=', crypto.hex(crypto.s2d_SM2Ciphertext(enc, 0)))
	assert(sm2:decrypt(enc, "C1C3C2") == '1122')
	
	local sig = assert(sm2:sign('1122'))
	print('sig=', crypto.hex(sig))
	print('sig(d2s)=', crypto.hex(crypto.d2s_SM2Signature(sig)))
	assert(sm2_pub:verify('1122',sig))

	local sig = assert(sm2:sign('1122', "RS"))
	print('sig(RS)=', crypto.hex(sig))
	print('sig(s2d)=', crypto.hex(crypto.s2d_SM2Signature(sig)))
	assert(sm2_pub:verify('1122',sig, "RS"))

	local sig = assert(sm2:digestSign('SM3', '1122'))
	print('dst_sig=', crypto.hex(sig))
	assert(sm2_pub:digestVerify('SM3', '1122',sig))
	
	local sig = assert(sm2:digestSign('SM3', '1122', "RS"))
	print('dst_sig(RS)=', crypto.hex(sig))
	assert(sm2_pub:digestVerify('SM3', '1122',sig, "RS"))
end

local function test_ecdh()
	local priKey = string.decode('') --input
	local otherPubKey = string.decode('') --input
	local ec = assert(pkey.new(priKey))
	local secret = ec:computeKey(otherPubKey)
	print('secret=', crypto.hex(secret))
end

local function test_jwks_ES256()
	function jwt_encode(s)
		return crypto.encode.encode_block(s):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
	end
	local pri = assert(pkey.generate('EC/', "prime256v1"))
	local n = pri:getString('RAWPUBKEY/')
	local x,y = n:sub(2,33), n:sub(34, 65)
	print(string.format('local token_prikey = "%s"', pri:getString('/PEM'):gsub("\n", "\\n")))
	print(string.format('local opts = {token_pubkey_x="%s", token_pubkey_y="%s"}', jwt_encode(x), jwt_encode(y)))
end

if pkey.d2i then
	test_rsa(generate_old('rsa', 1024, '\x01\x00\x01'))
	test_sm2(generate_old('sm2'))
	test_sm2_old(generate_old('sm2'))
end
test_rsa(generate('RSA/', 1024, '\x01\x00\x01'))
test_ec(generate('EC/', "prime192v1"))
test_ec(generate('EC/', "prime256v1"))
test_ec(generate('EC/', "secp384r1"))
test_sm2(generate('SM2/'))
test_jwks_ES256()
