#include <file.js>
#include <alg.js>
#include <crc.js>
#include "CommonFunc.txt"

//支持bitmap方式，不支持取断点
//var USE_BREAK_POINT = 0;		//1表示调用80C4取断点，0表示不取断点

var ENTL_ID = "31323334353637383132333435363738";

var a = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC";
var b = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93";
var Gx = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7";
var Gy = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0";

function SM2_verify(SM2_PubKey, id, SignData, plainData) 
{
	if (id == "")
		id = ENTL_ID;
	
	Debug.writeln("签名值：", SignData);
	Debug.writeln("SM2公钥：", SM2_PubKey);
	Debug.writeln("id: ", id);
	Debug.writeln("待签名源数据：", plainData);
	
	// 计算ZA值时，公钥值不包含首字节“04”
	var za = "0080" + id + a+ b+ Gx+ Gy +  Def.StrMid(SM2_PubKey, 1, -1);
	var Digest = Mgr.CreateInstance("LgnAlg.LgnDigest");
	Digest.Init("SM3");
	var md = Digest.Digest(za);
	Digest.Init("SM3");
	var md_Hash = Digest.Digest(md + plainData);
	Debug.writeln("md_Hash:", md_Hash);
	
	var Itrus = Mgr.CreateInstance("LgnAlg.LgnItrus");
	Itrus.sm2_pubkey_import(SM2_PubKey);		
	Itrus.sm2_verify(md_Hash, SignData);
	Debug.writeln("SM2_verify() 验证通过");
}

function ReadXFlash(Len)
{
	var ret = "";
	packetSize = 256;
	for(var offset=0;offset+packetSize<Len;offset+=packetSize)
		ret += Ins.ExecuteSingleEx("CMD[INS:FCDE020306" + Def.Int2Hex2(packetSize) + Def.Int2Hex(offset, 4) + "]");
	ret += Ins.ExecuteSingleEx("FCDE020306" + Def.Int2Hex2(Len - offset) + Def.Int2Hex(offset, 4) + "]");
	WriteFile("回读文件.bin", ret);
}

var UpdateTypeFlag = 0;		//0表示与ULC直连的324；1表示附属蓝牙芯片；2表示网关扩展板324
function Main()
{
	var PubK4FirmwareUpdateX = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31";
	var PubK4FirmwareUpdateY = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0";
	var PubK4FirmwareUpdateD = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3";
	
	var Def = Mgr.DefaultObject;
	//ComConnect("USB");
	// 选择读卡器
	Ins.ExecuteSingleEx("CMD[READER:SR_WinReaderU.dll||cdrom||4]");
	// 设置卡片类型：BASE，CARD, PBOC, PSAM, PK；默认为PBOC
	Ins.InsVar("CARDTYPE") = "BASE";
	Ins.ExecuteSingleEx("CMD[ATR]");

	var Start=new Date();
	Ins.ExecuteSingleEx("00A4000002DF20");
	Ins.ExecuteSingleEx("CMD[ENCOMM:11223344556677889900112233445577]");
	
	//获取UUID
	Ins.ExecuteSingleEx("E0B4011C022000");
	sm2_n = Ins.GetRet();
	Debug.writeln("sm2_n:" + sm2_n);
	Ins.ExecuteSingleEx("80DB001C081122334455667788");
	var signdata = Def.StrRight(Ins.GetRet(), 64);
	Debug.writeln("signdata:" + signdata);
	SM2_verify(sm2_n, "", signdata, "1122334455667788" + Def.StrLeft(Ins.GetRet(), Def.StrLen(Ins.GetRet())-64));
	var UUID1 = Def.StrMid(Ins.GetRet(), 2, 16);
	Debug.writeln("UUID1:" + UUID1);
	var UUID2 = Def.StrMid(Ins.GetRet(), 20, 16);
	Debug.writeln("UUID2:" + UUID2);
	//return;

	var SM2 = Mgr.CreateInstance("LgnAlg.LgnSM2.1");
	SM2("n") = PubK4FirmwareUpdateX+PubK4FirmwareUpdateY;
	SM2("d") = PubK4FirmwareUpdateD;
	
	var Ver = "0002";
	var ShellStart = Def.StrFullTail("00", "00", 16);
	var ShellEnd = Def.StrFullTail("FF", "FF", 16);
	var HashAlg = "06";	//SM3
	var SymAlg = "01";	//3DES6
	
	Debug.writeln("请确认要升级的文件路径");
	var Path = Mgr.PathObject;
	var CurWorkPath = Path.RemoveFileSpec(Vmm("SCRIPT_MAIN_FILE")) + "\\";
	if(0 == UpdateTypeFlag)
	{
		var FirmwarePath = CurWorkPath + "..\\DBCos324.bin";
	}
	else if(1 == UpdateTypeFlag)
	{
		var FirmwarePath = CurWorkPath + "..\\YG_BLE_binTest\\TDR_Ble_Slave_V1.0.25.bin";
		//var FirmwarePath = CurWorkPath + "..\\YG_BLE_binTest\\TDR_Ble_Slave_V1.0.25A.bin";
	}
	else if(2 == UpdateTypeFlag)
	{
		var FirmwarePath = CurWorkPath + "..\\LoopGateExtend\\DBCos324_LoopExtend.bin";
	}
	var	CosObj = Mgr.CreateInstance("LgnPacket.LgnFile");
	CosObj.Open(FirmwarePath);
	var CosLen = CosObj.Parameter("SIZE");
	Debug.writeln("CosLen:", CosLen);
	CosObj.Parameter("POINTER")=0;
	var Firmware =  CosObj.Read(CosLen, 0);
	//Firmware = Def.StrFullTail(Firmware, "FF", Def.StrLen(Firmware) + 16*1024)
	Debug.writeln("FW Len: ", Def.StrLen(Firmware)/1024, "K");
	//return;
	
	if(0 == UpdateTypeFlag || 2 == UpdateTypeFlag)
	{
		LoaderSize = 0x2000;
		Firmware = Def.StrMid(Firmware, LoaderSize);
	}
	else if(1 == UpdateTypeFlag)
	{
		//将bin文件补齐至1k整数倍
		if(Def.StrLen(Firmware) % 0x400)
			Firmware = Def.StrFullTail(Firmware, "FF", 0x400);
	}
	var FLen = Def.StrLen(Firmware);
	if(0 == FLen)
	{
		Debug.writeln("升级固件路径不正确！");
		throw -1;
	}
	
	/*
	//如果是从新版本升级到旧版本，需要固定固件大小为220K
	CodeZoneMaxSize = 220 * 1024;
	if(Def.StrLen(Firmware) > CodeZoneMaxSize)
		throw new Error("","目前代码只支持最大" + CodeZoneMaxSize + "(不含Loader)的固件")
	Firmware = Def.StrFullTail(Firmware, "FF", CodeZoneMaxSize);
	*/
	FLen = Def.StrLen(Firmware);
	
	FLen += 0x0f;
	FLen -= (FLen & 0x0f);
	Debug.writeln("FLen:", FLen);
	//return;
	Firmware = Def.StrFullTail(Firmware, "00", FLen);
	var SK = Def.StrFullTail("11", "11", 16);
	// SK = "8AEA2DE1752A57037201B977F637C1F6";
	
	PacketSize = 256;
	percent = 0;	
	
	//明文固件MAC
	var mac11 = Def.StrRight( Alg.Encrypt("SM4-CBC", SK, "00000000000000000000000000000000", Firmware, true), 16);		
	var CipherFirmware = Alg.Encrypt("SM4-ECB", SK, "00000000000000000000000000000000", Firmware, false)
	//密文固件MAC
	var mac22 = Def.StrRight( Alg.Encrypt("SM4-CBC", SK, "00000000000000000000000000000000", CipherFirmware, true), 16);	
	
	if(0 == UpdateTypeFlag)
	{
		deviceUUID = UUID1;
	}
	else if(1 == UpdateTypeFlag || 2 == UpdateTypeFlag)
	{
		deviceUUID = UUID2;
	}
	Debug.writeln("UUID:" + deviceUUID);
	var newUUID = Def.StrFullTail("A2", "A2", 16);
	//var startSN = "54445254657374303030303030303031";
	//var endSN = "54445254657374393939393939393939";
	var startSN = Def.StrFullTail("00", "00", 16);
	var endSN = Def.StrFullTail("FF", "FF", 16);
	var switchInfo = "000081" + deviceUUID + startSN + endSN + "40080100000000000000000000000000000000" + newUUID + "00005000" + Def.Int2Hex(FLen, 4) + mac11 + mac22;
	Debug.writeln("switchInfo:", switchInfo);
	var SM2 = Mgr.CreateInstance("LgnAlg.LgnSM2");
	SM2('n') = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D3190BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0";
	SM2('d') = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3";
	var signdata =  SM2.Sign_rs(switchInfo, "31323334353637383132333435363738");
	Ins.ExecuteSingleEx("CMD[INS:80DA000000" + Def.StrLen2Hex(switchInfo + signdata, 2) + switchInfo + signdata + "]", "[SW:<9001><9000>]");
	
	Ins.ExecuteSingleEx("E0B4011C022000");
	sm2_n = Ins.GetRet();
	var Itrus = Mgr.CreateInstance("LgnAlg.LgnItrus");
	Itrus.sm2_pubkey_import(sm2_n);
	var encryptSK = Itrus.sm2_encrypt(SK);
	Debug.writeln("encryptSK:" + encryptSK);
	//传入SK
	Ins.ExecuteSingleEx("CMD[INS:0020001C00" + Def.StrLen2Hex(encryptSK, 2) + encryptSK + "]", "[SW:<9001><9000>]");
	
	//
	var startoffset = 0;
	/*
	//支持bitmap方式，不支持取断点
	var breakpoint_flag = 0;
	if(1 == USE_BREAK_POINT)
	{
		//获取固件下载起始位置，支持断点续传
		Ins.ExecuteSingleEx("80c4000000");
		var startoffsetstr = Def.StrMid(Ins.GetRet(), 3, 4);
		var breakpointstr = Def.StrLeft(Ins.GetRet(), 1);
		Debug.writeln("startoffset:" + startoffsetstr);
		startoffset = Def.Hex2Int(startoffsetstr);
		Debug.writeln("startoffset:" + startoffset);
		breakpoint_flag = Def.Hex2Int(breakpointstr);
		Debug.writeln("breakpoint_flag:" + breakpoint_flag);
		//throw -1
	}
	*/
		
	//开始下载升级固件
	Ins.InsParam("DEBUGER") = null;
	for(offset = startoffset; offset + PacketSize < FLen; offset += PacketSize)
	{
		try
		{
			{
				var send_Data = Def.StrMid(CipherFirmware, offset, PacketSize);
				var crc = crc16c(send_Data,0);
				Ins.ExecuteSingleEx("CMD[INS:00D0000000" + Def.Int2Hex2(PacketSize+6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2) + "]");
			}
		}
		catch(e)
		{
			Debug.writeln("SW: ", Ins.GetSW());
			Debug.writeln("Ret: ", Ins.GetRet());
			Debug.writeln("offset: ", offset);
			throw -1;
		}
		
		if(percent != Math.floor((offset * 100 / FLen)))
		{
			percent = Math.floor((offset * 100 / FLen));
			Debug.writeln(percent + "%");
		}
	}
	var send_Data = Def.StrMid(CipherFirmware, offset);
	var crc = crc16c(send_Data,0);
	Ins.ExecuteSingleEx("CMD[INS:00D0000000" + Def.Int2Hex2(FLen - offset + 6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2) + "]");
	Ins.InsParam("DEBUGER") = Debug;
	
	Ins.ExecuteSingleEx("80c4000000");
	
	Debug.writeln("========等待KEY升级完成后重启...");
	Ins.ExecuteSingleEx("CMD[DELAY:0]");
	// 选择读卡器
	Ins.ExecuteSingleEx("CMD[READER:SR_WinReaderU.dll||cdrom||4]");
	// 设置卡片类型：BASE，CARD, PBOC, PSAM, PK；默认为PBOC
	Ins.InsVar("CARDTYPE") = "BASE";
	Ins.ExecuteSingleEx("CMD[ATR]");
	
	Ins.ExecuteSingleEx("00A4000002DF20");
	var tempstr = ""
	var strlen;
	
	Ins.ExecuteSingleEx("CMD[ENCOMM:11223344556677889900112233445577]");
	var cosVer = Ins.ExecuteSingleEx("F0F6020000");
	Debug.writeln("主COS Version: " + Def.Str2Hex(cosVer));
	if(1 == UpdateTypeFlag)
	{
		cosVer = Ins.ExecuteSingleEx("F0F6030000");
		Debug.writeln("Nordic Version: " + Def.Str2Hex(cosVer));
	}
	
	if(2 == UpdateTypeFlag)
	{
		//测试扩展324升级包是否正确
		cosVer = Ins.ExecuteSingleEx("FCD5261805FCD5100000");
		cosVer = Def.StrLeft(cosVer, Def.StrLen(cosVer)-2);
		Debug.writeln("扩展324 Version: " + Def.Str2Hex(cosVer));
		/*
		var SPIFlashAddr = 0X00050000;
		var FileOffset = 0;
		var FixDataLgth = 0x100;
		for(; FileOffset < FLen; FileOffset += FixDataLgth)
		{
			var databuf = Def.StrMid(CipherFirmware, FileOffset, FixDataLgth)
			crc = CRC.Do16(databuf, 0, 0xa001);	
			crc = Def.Int2Hex(crc,2)
			var cmd = "FCDA000008" + Def.Int2Hex2(FixDataLgth) + Def.Int2Hex2(SPIFlashAddr>>16) + Def.Int2Hex2(SPIFlashAddr&0xFFFF) + crc;
			ret = Ins.ExecuteSingleEx("CMD[INS:"+"FCD5261800"+Def.StrLen2Hex(cmd,2)+cmd+"]");
			var CmdSW = Def.StrRight(ret, 2);
			if("9000" == CmdSW)
			{
				SPIFlashAddr += FixDataLgth;
			}
			else
			{
				throw -1
			}
		}
		*/
	}
	
	Debug.writeln("测试结束");
}