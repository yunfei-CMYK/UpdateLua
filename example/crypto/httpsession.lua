local crypto = require("crypto")
local decode = crypto.decode
local digest = crypto.digest
local hmac = crypto.hmac
local bytes_to_key = crypto.bytes_to_key
local decrypt = crypto.decrypt
local pkey = crypto.pkey
local concat = table.concat

local DECODE_CHARS = {
    ["-"] = "+",
    ["_"] = "/",
    ["."] = "="
}
function session_decode(value)
    return decode((value:gsub("[-_.]", DECODE_CHARS)))
end

function session_decrypt(data, secret, self_key)
	local i, e, d, h = string.match(data, '^(.+)%|(.+)%|(.+)%|(.*)$')
	local i, e, d, h = session_decode(i), (e), session_decode(d), session_decode(h)

	print('i, e, d, h = ', i:encode(), e, d:encode(), h:encode())

	local k=hmac("sha1", i..e, secret)
	print('k=', k:encode())

	local key, iv = bytes_to_key("AES-256-CBC", "SHA512", i, k)
	print('key, iv = ', key:encode(), iv:encode())

	local d = decrypt("AES-256-CBC", d, key, iv)
	print('decrypt d = ', d)

	assert(self_key and hmac("sha1", concat{ i, e, d, self_key }, k) == h)
	return d
end

function jwt_decode(value)
    value = value:gsub("[-_]",  DECODE_CHARS)
	local reminder = #value % 4
	if reminder > 0 then
		value = value .. string.rep('=', 4 - reminder)
	end
	return decode(value)
end

function validate_id_token(jwt_str, pkey_str)
	local enc_hdr, enc_payload, enc_sign = string.match(jwt_str, '^(.+)%.(.+)%.(.*)$')
	print('enc_hdr, enc_payload, enc_sign = ', enc_hdr, enc_payload, enc_sign)
  
	local hdr, payload, sign = jwt_decode(enc_hdr), jwt_decode(enc_payload), jwt_decode(enc_sign)
	print('hdr, payload, sign = ', hdr, payload, sign:encode())
	
	local oid = string.decode('3031300D060960864801650304020105000420')
	local h = digest("SHA256", enc_hdr .. '.' .. enc_payload)
	print('h = ', h:encode())
	local rsa = pkey.d2i('rsa', pkey_str, 'pubkey')
	assert(rsa:verify(oid..h, sign))
end

print('===================session===================')
local session_secret="623q4hR325t36VsCD3g567922IC0073T"
local session_data="y9FRQAYdu3oPcLjFR4Uu_A..|1581138575|B1_WlB_ps1ZxC9SNkU3wd9M9UOIepWndshvfhtKhTeCAxUjTCAexDDSlNyLfZ4K_p8_KC1lh6UTsMsjmyFnFVCKkXJh5Um7PKMu7UJ8y8-fc0oS8eCf2cTVIsYP3K4BdP3lOUu_xu_NkjjPkC1rUOvFeGoieiM6bNs4ZR9Sg0rXr9XBRZTMnOjgJW5Dn-gfgJM-fR7jvLto0pRtJbq7Tu_RKhw2enlrF4NdKA-hkflWJHva7GWU4hdYXh9L9Eu6iVlZ_L3ZPsWv_i5lK_fVF60TLs9nm65bhIySLmN19_3C6GSjlbxJm_in3rrESXQLq4V2Z21ixhftdWuMo5E4V4LiZXd7VTspwE3wldGtp-9fl5rc1Wdzrp7cyTT22bbwZU605SPrUr2Vy9ufysVHAGyjJJtnMWu6j-sRiMnTAUmXuQiVOLP-fa2YE2Xjg2DevaciqewRC8UckC0InYl8fHVD5wjiretl1RKaNdBosMDZC2YEq1RndcgYQOxavvkRzAgLCv1W7SlQR_hujbdDN7e7XfiEwTCRLRG2hbqA_OamT0HPyFRgNhskVD-76R4DyY2ik1hF7ER0X1Py7hqBz3PWpe62rODsin0Yt2VHBrPDpCTBEfS5z9hkIbX3e1KsuzpaZbCObqcriFiKv8btfPA..|eXeEvqxRY5V5yanJaHkBGaBWR78."
local session_key = 'Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; Touch; rv:11.0) like Geckohttp';
local d = session_decrypt(session_data, session_secret, session_key)

print('===================token===================')
local jwt_str="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJJT3pwajM2NnB6Nk1sYkxDcTl3dERMZnhzbDZsU250bzdCMjFKUTdOdFdZIn0.eyJqdGkiOiI0NzVlNjZkNC04ZWE0LTQ0OGEtYWVjZi1hNWIzYzM0MWE3YjQiLCJleHAiOjE1ODExMzUyNzQsIm5iZiI6MCwiaWF0IjoxNTgxMTM0OTc0LCJpc3MiOiJodHRwOi8vMTkyLjE2OC4yNDQuMTM2OjgwODAvYXV0aC9yZWFsbXMvTkdJTlgiLCJhdWQiOiJuZ2lueCIsInN1YiI6IjNmNWEyNjI2LTVlYTYtNDhhNS05OGVhLTU2NDVkMmQ3ZDU3OSIsInR5cCI6IklEIiwiYXpwIjoibmdpbngiLCJub25jZSI6ImEyNjYzOTllOThmYjY1ZWY5Nzk4NmNlYjU2MTczZmIyIiwiYXV0aF90aW1lIjoxNTgxMTM0OTc0LCJzZXNzaW9uX3N0YXRlIjoiYTI2NWYxMzgtZmVlMS00NjJjLWE5NDYtY2E5NTQ0NDg3ZDZlIiwiYWNyIjoiMSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlcjEifQ.I4GS8ftOLX5kNnl3E5w33Suti3gsUen3pNrb02B4d6Ye50e0NlP8qzMEZ5Gyi2RZJ8RVh6chq6qpMHTqsR7aLGutqzyU9CHtqgCeyeNvF7hCX9D04l3hTl5fLx-ZZr74ycoiyieEDdJqJDetJ8n5Ps5FVvbYIZX8ybBHbzrdA8PIwEiHhMbXzLPsrOGKZTYS98ZBJvqlaEUrJm0GWg3hI_yvyoU5E0wjDDxtr4PsyoTFdlYkn5oIgsIoWYpanviQg1AsMtZLnEjZv7bIAw7uNN3zqHCws1CVs1aWvQIVf2YKYNY8RvJSEt15bXD-XCfceWLbVHVP1tV31XW4WQ0T9Q"
local pkey_str = string.decode("3082010A028201010099B17C42AC06681D76FD757B77CCFA86A51FE2E63052C38353FE3AEBF7B9931E64E421CFE4456D31DFFFC9B841D5D0D38BE8865F99B28FE253A396D187BED3193F374EF5030E868D0CDAA36C285940BF92206B6778A221BCF4A7165D7C35791CD797AA2C83643179B8A6A1D2582AF5A7AFF86FB06FD7E104AB21CE3ED36EDECEA063204BE13A6F46FAFD16D6D1F377E0A70FAEAB7C006FD33241388235D32E6400E3C34364E499E5B82F1387E73E5C3F2295F7C42D2DDD03C0AD734020E2D54D9C4CF1D8CE50753BC86E363DEAB19792D03BA8634C9E0E670275833D8ED1DEED437D6764EA5CF829EB8E059441C76CE092C52E4434F0F431D0B095EB916CFD7B0203010001")
validate_id_token(jwt_str, pkey_str)
