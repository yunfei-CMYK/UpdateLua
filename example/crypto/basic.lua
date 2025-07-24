
function tohex(s)
	return (s:gsub('.', function (c) return string.format("%02x", string.byte(c)) end))
end
function hexprint(s)
	print(crypto.hex(s))
end

crypto = require 'crypto'

print(crypto._COPYRIGHT)
print(crypto._DESCRIPTION)
print(crypto._VERSION)
print(crypto._VERSION_NUMBER)

print("")


-- TESTING HEX

local tst = 'abcd'
assert(crypto.hex, "missing crypto.hex")
local actual = crypto.hex(tst)
local expected = tohex(tst)
assert(actual == expected, "different hex results")


print(string.format('FLAG_PKCS1_PADDING=%08X', crypto.FLAG_PKCS1_PADDING))
print(string.format('FLAG_DER_FORMAT=%08X', crypto.FLAG_DER_FORMAT))
print(string.format('default_flags=%08X', crypto.default_flags()))

print('binary:' .. crypto.rand.bytes(10))
print('hexstring:' .. crypto.hex(crypto.rand.bytes(10)))
