local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
end

print("LuaCrypto version: " .. crypto._VERSION)
print("")


-- TESTING ENCRYPT
local testData = {
	{name='des-ecb', text='Hello world!', key='12345678', res='7a5e6b32a1fd824268a23360c402c157'},
	{name='des-cbc', text='Hello world!', key='12345678', iv='23456782', res='419e17d65982b72ddbb3f1562f05dd62'},
	{name='des-ede', text='Hello world!', key='1234567823456789', res='0e33dd1c8bcd5265c508cff6e5c7077e'},
	{name='des-ede-cbc', text='Hello world!', key='1234567823456789', iv='23456782', res='f362c437d77ce777980835b7c328cc81'},
	{name='des-ede3', text='Hello world!', key='12345678234567893456789a',res='cab352db3717277a9d5cf6945e72d7f8'},
	{name='des-ede3-cbc', text='Hello world!', key='12345678234567893456789a', iv='23456782',res='81653660b4eb68370141331a64335f83'},

	{name='aes-128-ecb', text='Hello world!', key='1234567823456789', res='ef9f6dd4351488e950ca79aaf679ad83'},
	{name='aes-128-cbc', text='Hello world!', key='1234567823456789', iv='234567823456789a', res='2bb615a85382d9061ebccec79448f77b'},
	{name='aes-192-ecb', text='Hello world!', key='123456782345678934567823', res='c36b032b044da5259ea67a0e1ab727e5'},
	{name='aes-192-cbc', text='Hello world!', key='123456782345678934567823', iv='234567823456789a', res='392f7bad830f00aeac7c24d3e8828fb5'},
	{name='aes-256-ecb', text='Hello world!', key='123456782345678934567823456789ab', res='b8b4d25ef1da784c9c0b67e883e209fa'},
	{name='aes-256-cbc', text='Hello world!', key='123456782345678934567823456789ab', iv='234567823456789a', res='019606d1c402fdfb7032e64e8420b07d'},
	--{name='aes-256-gcm', text='Hello world!', key='123456782345678934567823456789ab', iv='234567823456', res='2291801D969770CB0CD8A270'},

	{name='sm4-ecb', text='Hello world!', key='1234567823456789', res='57dec0bfa8013bceeebfab174082a1ed'},
	{name='sm4-cbc', text='Hello world!', key='1234567823456789', iv='234567823456789a', res='425ba633fe53b675436b3ebee03f17e0'}
}
for _,v in pairs(testData) do
	local res = assert(crypto.encrypt(v.name, v.text, v.key, v.iv))
	print(v.name .. '-encrypt]: ' .. crypto.hex(res))
	
	local ctx = crypto.encrypt.new(v.name, v.key, v.iv)
	local p1 = ctx:update(v.text)
	local p2 = ctx:final()
	local res2 = p1 .. p2
	assert(res == res2, "constructed result is different from direct")
	
	assert(crypto.hex(res) == v.res:upper(), v.name)

	assert(crypto.decrypt(v.name, res, v.key, v.iv) == v.text)
	
	local ctx = crypto.decrypt.new(v.name, v.key, v.iv)
	local p1 = ctx:update(res)
	local p2 = ctx:final()
	assert((p1..p2) == v.text, "constructed result is different from direct")
end

local function test_aes_gcm(name, keysize)
	print('\ntest_aes_gcm', name)
	local key = string.decode("B0F720861FE385330E891205D614F066B21D3AB7F5042937EE7A84346A862E1D")
	local iv = string.decode("6F6357DF61884E58DE6EF4EC")
	local aad = string.decode("626C6F621B00000000000000")
	local data = string.decode("789CF3482D4A55C82C5628CECF4D5548492C495428C957282EC92F4A55040084C70980")
	--tag(256) = 9639E6002D1F427A7A44B92DCE0E5D45
	--enc(256) = 6621190852D8D5FF3D5B3F0D9801996BFFF84567F744F6F145E4AD2009260CFA47C7A2
	local ctx = crypto.encrypt.new(name, key, iv)
	assert(ctx:control(-1, aad))
	local enc = ctx:update(data)
	ctx:final()
	local tag = ctx:control(0x10, 16) --EVP_CTRL_GCM_GET_TAG = 0x10
	print("tag=", string.encode(tag), "enc=", string.encode(enc))
	
	local ctx = crypto.decrypt.new(name, key, iv)
	assert(ctx:control(0x11, tag)) --EVP_CTRL_GCM_SET_TAG = 0x11
	assert(ctx:control(-1, aad))
	local dec = ctx:update(enc)
	print("dec=", string.encode(dec))
	assert(ctx:final()) --verify
end


print('\npadding TEST')
local v=testData[1]
local enc = crypto.encrypt(v.name, v.text, v.key, v.iv)
print(crypto.hex(enc))
local dec = crypto.decrypt(v.name, enc, v.key, v.iv, false) --nopadding
print(crypto.hex(dec))

test_aes_gcm("AES-256-GCM", 32)
test_aes_gcm("AES-128-GCM", 16)
