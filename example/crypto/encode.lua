local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
end

local encode = crypto.encode
local decode = crypto.decode

print("LuaCrypto version: " .. crypto._VERSION)
print("")

print(encode('11111111112222222222333333333344444444445555555555'))
print(decode('MTExMTExMTExMTIyMjIyMjIyMjIzMzMzMzMzMzMzNDQ0NDQ0NDQ0NDU1NTU1NTU1\nNTU='))

print(encode.encode_block('11111111112222222222333333333344444444445555555555'))
print(decode.decode_block('MTExMTExMTExMTIyMjIyMjIyMjIzMzMzMzMzMzMzNDQ0NDQ0NDQ0NDU1NTU1NTU1NTU='))

local en = encode.new()
print('update', en:update('1111111111222222222233333333334444444444'))
print('update', en:update('5555555555'))
print('final', en:final())

local de = decode.new()
print('update', de:update('MTExMTExMTExMTIyMjIyMjIyMjIzMzMzMzMzMzMzNDQ0NDQ0NDQ0NDU1NTU1NTU1\n'))
print('update', de:update('NTU='))
print('final', de:final())