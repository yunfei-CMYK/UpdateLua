local crypto = require((arg[-1]:sub(-9) == "lua51.exe") and "tdr.lib.crypto" or "crypto")
if not crypto.hex then
	crypto.hex = require("tdr.lib.base16").encode
end

local rand = crypto.rand

print("RAND version: " .. crypto._VERSION)
print("")


local N = 20
local S = 5

print(string.format("generating %d sets of %d random bytes using pseudo_bytes()", S, N))
for i = 1, S do
	local data = assert(rand.pseudo_bytes(N))
	print(table.concat({string.byte(data, 1, N)}, ","))
end
print("")

print(string.format("generating %d sets of %d random bytes using bytes()", S, N))
for i = 1, S do
	local data = assert(rand.bytes(N))
	print(table.concat({string.byte(data, 1, N)}, ","))
end
print("")

--RAND_seed() is equivalent to RAND_add() when num == entropy. 
if rand.add then
	print("RAND_add() may be called with sensitive data such as user entered passwords.")
	rand.add('\x11\x22\x33\x44', 777.99)
	print("")
end

if rand.status then
	print("status")
	print(rand.status())
	print("")
end
