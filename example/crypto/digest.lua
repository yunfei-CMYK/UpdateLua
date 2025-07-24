local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
local digest = crypto.digest
local hmac = crypto.hmac
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
	hmac.digest = hmac
end

print("LuaCrypto version: " .. crypto._VERSION)
print("")

print("hmac(v0.4.2):", crypto.hex(hmac('sha256', "text", "luacrypto")))

local testData = {
	{name='md5', text='Hello world!', res='86FB269D190D2C85F6E0468CECA42A20'},
	{name='sha1', text='Hello world!', res='D3486AE9136E7856BC42212385EA797094475802'},
	{name='sha256', text='Hello world!', res='C0535E4BE2B79FFD93291305436BF889314E4A3FAEC05ECFFCBB7DF31AD9E51A'},
	{name='sha384', text='Hello world!', res='86255FA2C36E4B30969EAE17DC34C772CBEBDFC58B58403900BE87614EB1A34B8780263F255EB5E65CA9BBB8641CCCFE'},
	{name='sha512', text='Hello world!', res='F6CDE2A0F819314CDDE55FC227D8D7DAE3D28CC556222A0A8AD66D91CCAD4AAD6094F517A2182360C9AACF6A3DC323162CB6FD8CDFFEDB0FE038F55E85FFB5B6'},
	{name='sm3', text='Hello world!', res='0E4EBFDE39B5789B457B3D9ED2D38057CEED47BE5D9728A88287AD51F5C1C3D2'}
}
for _,v in pairs(testData) do
	--digest
	local res = assert(digest(v.name, v.text), v.name)
	
	local d = digest.new(v.name)
	d:update(v.text)
	assert(d:final() == res, v.name)
	
	print(v.name .. ' hash: ' .. crypto.hex(res))
	assert(crypto.hex(res) == v.res, v.name)
	
	--hmac
	local res = assert(hmac.digest(v.name, v.text, "luacrypto"), v.name)
	
	local d = hmac.new(v.name, "luacrypto")
	d:update(v.text)
	assert(d:final() == res, v.name)
	
	print(v.name .. ' hmac: ' .. crypto.hex(res))
	--assert(crypto.hex(res) == v.hamcres, v.name)
end

do
	local res = digest('sha1', string.rep('1', 64) .. string.rep('2', 64))
	local md_data = '\x84\x5B\x61\xB4\xE3\x6D\xE8\x1C\xFA\x9D\xAE\x12\xAA\xB7\x3F\xCB\x1F\x96\x84\xD4'
	local d = digest.new('sha1')
	d:update(string.rep('1', 64))
	assert(d:get_md_data() == md_data)
	
	local d2 = digest.new('sha1')
	d2:md_data(md_data .. "\x00\x02\x00\x00") --bitSize
	d2:update(string.rep('2', 64))
	assert(d2:final() == res)
	print('test md_data ok.')
end

do
	local res = digest('sha1', string.rep('1', 64) .. string.rep('2', 64))
	local md_data = '\x84\x5B\x61\xB4\xE3\x6D\xE8\x1C\xFA\x9D\xAE\x12\xAA\xB7\x3F\xCB\x1F\x96\x84\xD4'
	local md_data_be = string.gsub(md_data, "....", function(c4) return string.reverse(c4) end) 
	local d = digest.new('sha1')
	d:update(string.rep('1', 64))
	assert(d:get_md_data(0, true) == md_data_be)
	
	local d2 = digest.new('sha1')
	d2:md_data(md_data_be .. "\x00\x00\x02\x00", true) --bitSize
	d2:update(string.rep('2', 64))
	assert(d2:final() == res)
	print('test md_data(bitEnd) ok.')
end

function get_z(pubKey, id)
	local abxy = '\xFF\xFF\xFF\xFE\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFC\x28\xE9\xFA\x9E\x9D\x9F\x5E\x34\x4D\x5A\x9E\x4B\xCF\x65\x09\xA7\xF3\x97\x89\xF5\x15\xAB\x8F\x92\xDD\xBC\xBD\x41\x4D\x94\x0E\x93\x32\xC4\xAE\x2C\x1F\x19\x81\x19\x5F\x99\x04\x46\x6A\x39\xC9\x94\x8F\xE3\x0B\xBF\xF2\x66\x0B\xE1\x71\x5A\x45\x89\x33\x4C\x74\xC7\xBC\x37\x36\xA2\xF4\xF6\x77\x9C\x59\xBD\xCE\xE3\x6B\x69\x21\x53\xD0\xA9\x87\x7C\xC6\x2A\x47\x40\x02\xDF\x32\xE5\x21\x39\xF0\xA0'
	local data = '\x00\x80' .. (id or '\x31\x32\x33\x34\x35\x36\x37\x38\x31\x32\x33\x34\x35\x36\x37\x38') .. abxy .. pubKey:sub(-64)
	return digest('sm3', data)
end
print('get_z:' .. crypto.hex(get_z('\x25\x31\xC9\xE5\x87\x1A\x16\x0D\x9F\xCC\xD2\xA5\xAE\x4F\x0F\x2A\x9F\xE5\xDD\x17\x9F\x76\xDA\x45\x33\x50\x6E\xFD\x69\xCE\xAE\x53\xEC\x2B\x3F\xA6\x18\x3F\x18\xF8\x9E\x89\xD2\x41\x7C\x78\xEB\x56\xEC\x29\x2F\xE6\x96\x60\x48\xE1\x78\xA1\x48\x5C\xEA\x11\x6D\x1F'))) --3292608000a6452928dc242407ff7656f04e73b1a5f930a89bf1ec3b145a4a9e
