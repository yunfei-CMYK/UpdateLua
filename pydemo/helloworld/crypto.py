import rsa

(pub, pri) = rsa.newkeys(2048)

message = "hello world".encode()
crypto = rsa.encrypt(message, pub)
print(crypto)
print(len(crypto))


plain = rsa.decrypt(crypto,pri)
print(plain)
print(plain.decode())
