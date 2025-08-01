//#include "F:\\WorkDir\\Tools\\lgntest\\notepad++\\script\\CommonFunc.txt"
var Def = Mgr.DefaultObject;

var Simulator = false;
function WarningBeep()
{
	var uiMgr = Mgr.CreateInstance("LgnUI.LgnManager");
	var proc = uiMgr.CreateFunction("Kernel32.dll", "Beep");
	proc.AddParameter(0, "LONG", 0); // 返回值
	proc.AddParameter(1, "LONG", 40);
	proc.AddParameter(2, "LONG", 200);
	proc.Execute();
}
//用于一代Key的按键查询
function ButtonScanning()
{
	var uiMgr = Mgr.CreateInstance("LgnUI.LgnManager");
	var proc = uiMgr.CreateFunction("Kernel32.dll", "Beep");
	proc.AddParameter(0, "LONG", 0); // 返回值
	//proc.AddParameter(1, "LONG", 40);
	proc.AddParameter(1, "LONG", 20);
	//proc.AddParameter(2, "LONG", 500);
	proc.AddParameter(2, "LONG", 20);
	//proc.Execute();

	Ins.ExecuteSingleEx("FD07000000", "[SW:<>]");
	var loop = 0;
	while(Def.Hex2Int(Def.StrLeft(Ins.GetRet(), 1)) != 0x80)
	{
		if(true == Simulator)
		{
			Ins.ExecuteSingleEx("FD090D0000", "[SW:<>]");
		}
		else
		{
			if(loop++>10)
			{
				loop = 0;
				proc.Execute();
			}
		}
		//Ins.ExecuteSingleEx("EB1E00D100");
		//Ins.ExecuteSingleEx("CMD[DELAY:0]");
		Ins.ExecuteSingleEx("FD07000000", "[SW:<>]");
	}
}

function crc16c(s,seed)
{
	var Def = Mgr.DefaultObject;
	var crc = seed;
	var len = Def.StrLen(s);
	for(var j=0;j<len;j++)
	{
		var s_s = Def.Hex2Int(Def.StrMid(s, j, 1));
		for(var i=0;i<8;i++)
		{
			var bit=crc&1;
			if(s_s&1)
				bit^=1;
			if(bit)
				crc^=0x4002;
			crc>>=1;
			if(bit)
				crc|=0x8000;
			s_s>>=1;
		}
	}
	return crc;
}

/*
0:DES
1:3DES(2KEY)
2:SCB2
3:SSF33
4:AES128
5:AES192
6:AES256
7:3DES(3KEY)
*/
function AlgID2CBCAlgName(alg)
{
	switch(alg)
	{
		case 0:
			return "DES-CBC";
		case 1:
			return "DES-EDE-CBC";
		case 2:
			return "SCB2-CBC";
		case 3:
			return "SSF33-CBC";
		case 4:
		case 5:
		case 6:
			return "AES-CBC";
		case 7:
			return "DES-EDE3-CBC";
		default:
			Debug.writeln("不支持的算法");
			throw -1;
	}
}
function AlgID2AlgName(alg)
{
	switch(alg)
	{
		case 0:
			return "DES-ECB";
		case 1:
			return "DES-EDE";
		case 2:
			return "SCB2";
		case 3:
			return "SSF33";
		case 4:
		case 5:
		case 6:
			return "AES-ECB";
		case 7:
			return "DES-EDE3";
		default:
			Debug.writeln("不支持的算法");
			throw -1;
	}
}
function Alg2BlockSize(Alg)
{
	switch(Alg)
	{
		case 0:
		case 1:
		case 7:
			return 8;
		case 2:
		case 3:
		case 4:
		case 5:
		case 6:
			return 16;
		default:
			Debug.writeln("不支持的算法:", Alg);
			throw -1;
	}
}
function Alg2KeyLen(Alg)
{
	switch(Alg)
	{
		case 0:
			return 8;
		case 1:
		case 3:
		case 4:
			return 16;
		case 5:
		case 7:
			return 24;
		case 2:
		case 6:
			return 32;
		default:
			Debug.writeln("不支持的算法");
			throw -1;
	}
}
function AlgName2BlockLen(AlgName)
{
	switch(AlgName)
	{
		case "DES-ECB":
		case "DES-CBC":
		case "DES-EDE":
		case "DES-EDE-CBC":
		case "DES-EDE3":
		case "DES-EDE3-CBC":
			return 8;
		case "SCB2":
		case "SSF33":
		case "AES-ECB":
		case "AES-CBC":
			return 16;
		default:
			Debug.writeln("不支持的算法");
			throw -1;
	}
}

//var SymCrypto = Mgr.CreateInstance("LgnAlg.LgnCipher");

function SymCBCEncrypt(iv, plain, key, AlgName)
{
	var SymCrypto = Mgr.CreateInstance("LgnAlg.LgnCipher");
	//Debug.writeln(SymCrypto.Help());
	//Debug.writeln(SymCrypto.Help("Update"));
	if(0 == iv)
		iv = Def.StrFullTail("00", "00", AlgName2BlockLen(AlgName));
	SymCrypto.Init(AlgName, key, iv, true);
	var ret = SymCrypto.Update(plain);
	SymCrypto.Final();
	return ret;
}

function SymEncrypt(plain, key, AlgName)
{
	var SymCrypto = Mgr.CreateInstance("LgnAlg.LgnCipher");
	//Debug.writeln(SymCrypto.Help("Update"));
	var iv = Def.StrFullTail("00", "00", AlgName2BlockLen(AlgName));
	SymCrypto.Init(AlgName, key, iv, true);
	var ret = SymCrypto.Update(plain);
	SymCrypto.Final();
	return ret;
}
function SymDecrypt(plain, key, AlgName)
{
	var SymCrypto = Mgr.CreateInstance("LgnAlg.LgnCipher");
	
	var iv = Def.StrFullTail("00", "00", AlgName2BlockLen(AlgName));
	SymCrypto.Init(AlgName, key, iv, false);
	var ret = SymCrypto.Update(plain);
	//SymCrypto.Final();
	return ret;
}
var rand;
function EncryptPin(pin, id)
{
	var RSA = Mgr.CreateInstance("LgnAlg.LgnRSA");
	//Debug.writeln(RSA.help());
	//Debug.writeln(RSA.help("PublicEncrypt"));
	var PinAttr = Ins.ExecuteSingleEx("10F6" + Def.Int2Hex1(id) + "1004");
	var ProtectRsaID = (Def.Hex2Int(Def.StrMid(PinAttr, 3, 1)) & 0x7F) >> 2;
	
	//Debug.writeln("保护密钥ID: ", ProtectRsaID);
	RSA("n") = Ins.ExecuteSingleEx("E0B401" + Def.Int2Hex1(ProtectRsaID) + "023000");
	//RSA("n") = "EC74E1F3FCF0800E1EC802F6D1ACE429C5890878B6344D2B849D0F86800DDD6743B210A1525D5C68902BE80DECF086E910265CC4EF317D116E2FE962D094CA616AE777365645587055ACBD48089B0D2C8D6C0E656B026180715A2EAAD22BB680B900D3FB29E15FB64DDEA5ECB6D7EE06FDECE4C68A3620E72093964F224BB1AB";
	RSA("d") = "057A1799BD2C1CEB36CF4F32445D0AD3E4DD6DB2CE159C0BFC005F51B039A1FD385631886B0DFA8BF97AEADF17B3E28C1771AC086BB9EBB9B1A1AE78397898CF697236F2D895E3BF2C2E975A4C39FA52C240BD7024E13A3A9BE176C3BB81B33DC94F96C0135A75AC87026244738238623D1384627885EDD634B6BCE59F169451";
	RSA("e") = "010001";
	rand = Ins.ExecuteSingleEx("0084000008");
	var CipherPin = RSA.PublicEncrypt(pin + rand, 1);
	Debug.writeln(CipherPin);
	return CipherPin;
}

function VerifyPin(pin, pinID)
{
	var CipherPin = EncryptPin(pin, 0);
	Ins.ExecuteSingleEx("CMD[INS:842000" + Def.Int2Hex1(pinID) + "00" + Def.Int2Hex2(Def.StrLen(CipherPin)) + CipherPin + "]", "[SW:<>]");
}

function CalcDigest(Alg, Message)
{
	var Digest = Mgr.CreateInstance("LgnAlg.LgnDigest");
	//Debug.writeln(Digest.help());
	Digest.Init(Alg);
	Digest.Update(Message);
	return Digest.Final();
}


var RsaN = "ED676580A0158DC70BAF531144BA678FE446F6BF9DB376D5F50F4545439EF193E0FFA4CE1E91476570A8FEBFBAD054FF864E30D43056546701B74C8B755BEB023E25F7DD312446FEB03639318E3E97294E7C8FDDBB2407C49C22A88489C0AF87899AD1AD771C3DEC33C9AFDB95BF823DFDE5D34F37CBA720EFC4FB9B3374D397";
var RsaE = "00010001";
var RsaD = "3C998D1E653EBB3F18EB7B1FC85470C51937481B278D3D036697AC4DFEF1DEA6A9E377D529965A0C39D2D99C657A7287FB67902D49DD6F940FAB137DF1CA31D595DDC0E87DC221521CB77DE7C4574506F78B863A26A28C89FF44971825DA9ED78C22BDF6813300A5216090E686D36F38C6F138FF818C31255FF3A079E8EF5E49";
var RsaP = "F6DA4E5FA0213CF29FF6EE6B719359494EFD0EA2AAADB018624D48D001223C10C55F072DEF8D0F6F1C96E1903C98A3DDC66C639E5828D749E01292D1C061EBFB";
var RsaQ = "F63374E036940C0C4EC7C8834406EE24DA0B6FD2363BEDDC6EBDD13D8E3154E6D82740D0BD244F381EE680824A14466A873B7DD9A1BDAC448D1677B2EAE3E815";
var RsaIQMP = "B89CD0FC4A5DFFDBC21A54E31B92BF78B6551405C1A8DCA9BA93FF1AD2725CD12F9A052CDC239E4CE9F5BC2F082BD50E8E0F459FEEDB2CCDE4DE8E29E2629968";
var RsaDMP1 = "33F7CF8A18270732B8F47E4B065513F5F7F8146DB06AF2689FC14F73E2D93735FCA73DD6B0D8CC8802C7CCE2D5AEF8C886AE68E67BFED51C0B5D3DA584CFD8A3";
var RsaDMQ1 = "5B177ECED662C0726D538DE4C36EACFE058EE5B8A948532193F7B74B47290978BFD10632354911E679C85F13D5C4DAA8DF902B683267B32D49E65E335CA52661";
/*
var RsaN = "B66EB89236DE4AA0798D9312612C245AE566F51A6B18893F16F455C21CCFC61EB2DC16BE01C4949CD9268ADDBE688368B41903C838147F199B1BC06B1206F5523EAED285AD0016E41657677801A5DB1616ED7AF9543F9A34A03836ED81136EA64A182E6274C8E2F0A04A47C559978EECC06F51457678E41FA8C0343882EA1FB015C6D82A96B1DFA4FD5FC7C9B782104CE2A74933CA75B5475D70FE7734BA0284780048690C8FB4C6457BA0E34B346B344938B2A22F8A5BD2E6BA2D2E739AF6643A3FBDF0BDC332ACC9CB27062DA53D296B5D3D41FE20E6F6B74721AE3072626556FCE6A8D69F63868879F27197848A0C779F9E404DB35B5308B18487EE1FE5B1";
var RsaE = "00010001";
var RsaD = "4FBD99C39F640EAE923305C414E15C8AB697082FA1FC3991701120A31640E3526BCFB3C91DB0B55CD1B5FD20EBA77738FEEFA82D8E05B78093C1CF9B7D67B93757DAC67E539E24635238A62B585D0CA45D25348962FFE2017ABED7937CC5E7A99BDD71F8EB1F1BC31DED19EDF33941E9CE3B5A04C8C212C49BD8577B140E0E0706B1033810F7CECCD71664869279E8FE626D3DABF974EA9B03A3B6FF60628A9F2B90B6EB313F3574B72F7C7A4AE255E186F06A0E2694D33B0DEEE742FAE5DDBCD5E4FCAC47D4F91592DC952CF6A37C9AFBDD3C167E7FD6CD4E1C75A3AEB93D5B0E9F8349888F13136EE5A673F90300A9AF0F27BC80B72FBFBEFA3C04AAB72139";
var RsaP = "D90317B3EDBF1A68D03B4012C201EAA65ECB598FC7671F2586AB8A79E7E9AC5DD7FF6974A4D685F949A8FF40C1E2ADDA3E21B66C065FA28A10130D4ECE11EF8A155C1134914607A7B6E1F520F2E3E32572649DED444CD665BCBC053B5A38506A4F425E52D02B2A48BA3CA938017650AE042374788DF3E5D8F60E3856C4CFD5EB";
var RsaQ = "D7353B02EDA7944F566B4B4FDFDA04DE3B42CBDD801BDDA4E258C27196EF71EDBB82F2E6F6828E3A2A8F4E343EE398E42DDA9E35E7A6FFB4E3EEE015AD24497124363574718A551FE266B817B49C9C5B70C6384FB752B8B5657B54C8BB9F8033F06AACDC1CCA4E0F3131C80A2C45B9484A6790E50A15FF5C858BBB4D77597FD3";
var RsaIQMP = "1AA3D90B0ABCBAEE4B1DDF98864F9E88D22206AC7BC863DE92D29F025A9BC1D785613C9997F25A05ED2D0C9822E87107579BBF5AA1E6150FDE7EAE4BA669B453BC9C82362E56F1CB043BB1B7DA308D7AAE304BDE139178182E9C9224EF2EFA5F13A79A638711683E048538567B141666C4FA2B6612A99FA22EDB50A4F0B3A4B2";
var RsaDMP1 = "D5F5859E21CEA4142911F1D74CAEA512892DC6CCCA55F2D085D9857B31DB22D5978BBC06842AFA0651C8AC79C56F5FE76810C711F4AABFCF8D8FAB34425A4EA8FEEC3A0E7118F19D3AE3C7524807C5417B6A9686832B9ACACDED36DF50D16AFF95CBA2C1D57A6983311373E7C3114AF4772219C86E74C4EE4792B79B5D0A6927";
var RsaDMQ1 = "6A12748996F598261AA43BB49CD2EABF565A2FFD76DD453BB5CCA5DA32D8C640B4C17053E280AAF58470A9CD1A8A379B8FF64730AE832359D756AFE03F3CB96E28B90753E37A994663E2D92DE5F9A31F76D05C84FE08A9BDCECD2116E753506F493A6B04FAB3C411BCDF9A875916ECA1F2FA64F25F2C447727E39D682B4153BD";
*/
function JS_ImportRsaKey(keyIndex)
{
	var KeyLen = Def.StrLen(RsaN);
	var KeyTLV = "";
	KeyTLV += "01" + Def.Int2Hex2(Def.StrLen(RsaN)) + RsaN;
	KeyTLV += "02" + Def.Int2Hex2(Def.StrLen(RsaE)) + RsaE;
	KeyTLV += "04" + Def.Int2Hex2(Def.StrLen(RsaP)) + RsaP;
	KeyTLV += "05" + Def.Int2Hex2(Def.StrLen(RsaQ)) + RsaQ;
	KeyTLV += "06" + Def.Int2Hex2(Def.StrLen(RsaIQMP)) + RsaIQMP;
	KeyTLV += "07" + Def.Int2Hex2(Def.StrLen(RsaDMP1)) + RsaDMP1;
	KeyTLV += "08" + Def.Int2Hex2(Def.StrLen(RsaDMQ1)) + RsaDMQ1;
	Ins_ExecuteCmd("CMD[INS:e048000000" + Def.Int2Hex2(2 + Def.StrLen(KeyTLV)) + Def.Int2Hex1(keyIndex) + Def.Int2Hex1(KeyLen/8) + KeyTLV + "]");
}
function Alg2DigestID(Alg)
{
	switch(Alg)
	{
		case 0:
			return "3021300906052B0E03021A05000414";
		case 1:
			return "3020300C06082A864886F70D020505000410";
		case 2:
			return "3031300D060960864801650304020105000420";
		case 3:
			return "3041300D060960864801650304020205000430";
		case 4:
			return "3051300D060960864801650304020305000440";
		default:
			Debug.writeln("Alg:", Alg);
			Debug.writeln("暂时不支持该摘要算法");
			throw -1;
	}
}
function Alg2DigestName(Alg)
{
	switch(Alg)
	{
		case 0:
			return "SHA1";
		case 1:
			return "MD5";
		case 2:
			return "SHA256";
		case 3:
			return "SHA384";
		case 4:
			return "SHA512";
		case 6:
			return "SM3";
		default:
			Debug.writeln("Alg:", Alg);
			Debug.writeln("暂时不支持该摘要算法");
			throw -1;
	}
}
function AlgName2DigestAlg(AlgName)
{
	if("SHA1" == AlgName)
		return 0;
	if("MD5" == AlgName)
		return 1;
	if("SHA256" == AlgName)
		return 2;
	if("SHA384" == AlgName)
		return 3;
	if("SHA512" == AlgName)
		return 4;
	Debug.writeln("Alg:", Alg);
	Debug.writeln("暂时不支持该摘要算法");
	throw -1;
}
function Alg2DigestLen(Alg)
{
	switch(Alg)
	{
		case 0:
			return 20;
		case 1:
			return 16;
		case 2:
			return 32;
		case 3:
			return 48;
		case 4:
			return 64;
		case 6:
			return 32;
		default:
			Debug.writeln("Alg:", Alg);
			Debug.writeln("暂时不支持该摘要算法");
			throw -1;
	}
}
function Alg2DigestBlockLen(Alg)
{
	switch(Alg)
	{
		case 0:
		case 1:
		case 2:
			return 64;
		case 3:
		case 4:
			return 128;
		default:
			Debug.writeln("Alg:", Alg);
			Debug.writeln("暂时不支持该摘要算法");
			throw -1;
	}
}

function CosDigestModuleTest()
{
	for(var Alg = 3; Alg < 4; Alg++)
	{
		Debug.writeln(Alg2DigestName(Alg), "测试");
		for(var len=1200;len<10000;len+=100)
		{
			if((len % 100) == 1)
				Debug.writeln("当前长度:", len);

			var data = Def.StrFullTail("5A", "5A", len)
			Ins.ExecuteSingleEx("CMD[INS:F0F4" + Def.Int2Hex1(Alg) + "0000" + Def.Int2Hex2(len) + data + "]", "[SW:<>]");
			if("6A00" == Ins.GetSW())
				break;
			var Digest = CalcDigest(Alg2DigestName(Alg), data);
			if(Ins.GetRet() != Digest)
			{
				Debug.writeln("data:", data);
				Debug.writeln("PC计算摘要：", Digest);
				Debug.writeln("COS计算摘要:", Ins.GetRet());
				throw -1;
			}
		}
	}
}

function CalcDigest(Alg, Message)
{
	var Digest = Mgr.CreateInstance("LgnAlg.LgnDigest");
	//Debug.writeln(Digest.help());
	Digest.Init(Alg);
	Digest.Update(Message);
	return Digest.Final();
}
//Alg : "MD5" "SHA1" "SHA256" "SHA384" "SHA512"
function HMac(Seed, AlgName, Message)
{
	var Digest = Mgr.CreateInstance("LgnAlg.LgnDigest");
	var Alg = AlgName2DigestAlg(AlgName);
	
	var SeedLen = Def.StrLen(Seed);
	
	if(SeedLen > Alg2DigestBlockLen(Alg))
	{
		Digest.Init(AlgName);
		Digest.Update(Seed);
		Seed = Digest.Final();
		Debug.writeln("Calced Seed:", Seed);
		SeedLen = Alg2DigestLen(Alg);
		
	}
	else
		Seed = Def.StrFullTail(Seed, "00", Alg2DigestBlockLen(Alg));
	var k_ipad = "";
	var k_opad = "";
	var i;
	for(i=0;i<SeedLen;i++)
	{
		
		k_ipad += Def.Int2Hex1(Def.Str2Int(Def.StrMid(Seed, i, 1)) ^ 0x36);
		k_opad += Def.Int2Hex1(Def.Str2Int(Def.StrMid(Seed, i, 1)) ^ 0x5C);
	}
	for(;i<Alg2DigestBlockLen(Alg);i++)
	{
		k_ipad += "36";
		k_opad += "5C";
	}
	//Debug.writeln("k_ipad:", k_ipad);
	//Debug.writeln("k_opad:", k_opad);
	
	Digest.Init(AlgName);
	Digest.Update(k_ipad);
	Digest.Update(Message);
	//Debug.writeln("k_ipad + Message:", k_ipad, Message);
	var TmpDigest = Digest.Final();
	//Debug.writeln("TmpDigest:", TmpDigest);
	
	//Debug.writeln("k_opad + TmpDigest:", k_opad, TmpDigest);
	Digest.Init(AlgName);
	Digest.Update(k_opad);
	Digest.Update(TmpDigest);
	return Digest.Final();
}
function OCRA_Otp(Seed, QS)
{
	if(Def.StrLen(QS) != 20)
	{
		Debug.writeln("Len of QS 不等于20")
		throw -1;
	}
	var DataInput = Def.Hex2Str("OCRA-1:HOTP-SHA1-8:QH40");
	
	DataInput += "00";
	DataInput += Def.StrFullTail(QS, "00", 128);
	//DataInput = Def.StrFullTail(DataInput, "00", 128);
	Debug.writeln("DataInput:", DataInput);
	var Digest = HMac(Seed, "SHA1", DataInput);
	var offset = Def.Str2Int(Def.StrRight(Digest, 1)) & 0xF;
	
	var otp = Def.Str2Int(Def.Int2Hex1(Def.Str2Int(Def.StrMid(Digest, offset, 1)) & 0x7F) + Def.StrMid(Digest, offset + 1, 3));
	Debug.writeln("otp:", otp);
	otp = otp % 100000000;
	return otp;
}
//Ins.InsParam("DEBUGER") = null;