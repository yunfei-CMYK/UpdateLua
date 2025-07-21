#include <file.js>
#include <alg.js>
#include <crc.js>
#include "CommonFunc.txt"

//֧��bitmap��ʽ����֧��ȡ�ϵ�
//var USE_BREAK_POINT = 0;		//1��ʾ����80C4ȡ�ϵ㣬0��ʾ��ȡ�ϵ�

var UpdateTypeFlag = 0;		//0��ʾ��ULCֱ����324��1��ʾ��������оƬ��2��ʾ������չ��324
var CommType = 1;			//0��ʾʹ��USBͨ����1��ʾʹ��ULCͨ��
var DeviceID = 2;			//��ʾʹ��ULCͨ��ʱĿ���豸ID

var ENTL_ID = "31323334353637383132333435363738";

var a = "FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC";
var b = "28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93";
var Gx = "32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7";
var Gy = "BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0";

function SM2_verify(SM2_PubKey, id, SignData, plainData) 
{
	if (id == "")
		id = ENTL_ID;
	
	Debug.writeln("ǩ��ֵ��", SignData);
	Debug.writeln("SM2��Կ��", SM2_PubKey);
	Debug.writeln("id: ", id);
	Debug.writeln("��ǩ��Դ���ݣ�", plainData);
	
	// ����ZAֵʱ����Կֵ���������ֽڡ�04��
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
	Debug.writeln("SM2_verify() ��֤ͨ��");
}

function ReadXFlash(Len)
{
	var ret = "";
	packetSize = 256;
	for(var offset=0;offset+packetSize<Len;offset+=packetSize)
		ret += Ins.ExecuteSingleEx("CMD[INS:FCDE020306" + Def.Int2Hex2(packetSize) + Def.Int2Hex(offset, 4) + "]");
	ret += Ins.ExecuteSingleEx("FCDE020306" + Def.Int2Hex2(Len - offset) + Def.Int2Hex(offset, 4) + "]");
	WriteFile("�ض��ļ�.bin", ret);
}

function ULC_Send_APDU(apdu)
{
	var ret = "";
	if(0 == CommType)
	{
		ret = Ins.ExecuteSingleEx(apdu);
	}
	else
	{
		ret = Ins.ExecuteSingleEx("FCD550" + Def.Int2Hex(DeviceID, 1) + Def.Int2Hex(Def.StrLen(apdu), 3) + apdu, "[SW:<6FF3><9000>]");
		if("9000" == Ins.GetSW())
		{
			var sw = Def.StrRight(ret, 2);
			if("9000" == sw)
			{
				return Def.StrLeft(ret, Def.StrLen(ret)-2);
			}
			else
			{
				throw -1;
			}
		}
		else
		{
			ret = Ins.ExecuteSingleEx("FCD550" + Def.Int2Hex(DeviceID, 1) + Def.Int2Hex(Def.StrLen(apdu), 3) + apdu, "[SW:<6FF3><9000>]");
			if("9000" == Ins.GetSW())
			{
				var sw = Def.StrRight(ret, 2);
				if("9000" == sw)
				{
					return Def.StrLeft(ret, Def.StrLen(ret)-2);
				}
				else
				{
					throw -1;
				}
			}
			else
			{
				ret = Ins.ExecuteSingleEx("FCD550" + Def.Int2Hex(DeviceID, 1) + Def.Int2Hex(Def.StrLen(apdu), 3) + apdu, "[SW:<6FF3><9000>]");
				if("9000" == Ins.GetSW())
				{
					var sw = Def.StrRight(ret, 2);
					if("9000" == sw)
					{
						return Def.StrLeft(ret, Def.StrLen(ret)-2);
					}
					else
					{
						throw -1;
					}
				}
				else
				{
					throw -1;
				}
			}
		}
	}
}

function Main()
{
	var PubK4FirmwareUpdateX = "A88BCDF98122608F18B00EB03A410CA1CD6D7E4124832F4BC663861C45FE5D31";
	var PubK4FirmwareUpdateY = "90BEE3759C25A299EF397C87F69A421CE0D9325F36FC0F4FA0027B3012F8ABA0";
	var PubK4FirmwareUpdateD = "9E1F3B2512384509767D7A5A5D03701F26A6428B66BB64434DC8074D2D1239B3";
	
	var Def = Mgr.DefaultObject;
	//ComConnect("USB");
	// ѡ�������
	Ins.ExecuteSingleEx("CMD[READER:SR_WinReaderU.dll||cdrom||4]");
	// ���ÿ�Ƭ���ͣ�BASE��CARD, PBOC, PSAM, PK��Ĭ��ΪPBOC
	Ins.InsVar("CARDTYPE") = "BASE";
	Ins.ExecuteSingleEx("CMD[ATR]");

	var Start=new Date();
	ULC_Send_APDU("00A4000002DF20");
	//Ins.ExecuteSingleEx("CMD[ENCOMM:11223344556677889900112233445577]");
	
	//��ȡUUID
	var ret = ULC_Send_APDU("E0B4011C022000");
	sm2_n = ret;
	Debug.writeln("sm2_n:" + sm2_n);
	ret = ULC_Send_APDU("80DB001C081122334455667788");
	var signdata = Def.StrRight(ret, 64);
	Debug.writeln("signdata:" + signdata);
	SM2_verify(sm2_n, "", signdata, "1122334455667788" + Def.StrLeft(ret, Def.StrLen(ret)-64));
	var UUID1 = Def.StrMid(ret, 2, 16);
	Debug.writeln("UUID1:" + UUID1);
	var UUID2 = Def.StrMid(ret, 20, 16);
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
	
	Debug.writeln("��ȷ��Ҫ�������ļ�·��");
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
		//��bin�ļ�������1k������
		if(Def.StrLen(Firmware) % 0x400)
			Firmware = Def.StrFullTail(Firmware, "FF", 0x400);
	}
	var FLen = Def.StrLen(Firmware);
	if(0 == FLen)
	{
		Debug.writeln("�����̼�·������ȷ��");
		throw -1;
	}
	
	/*
	//����Ǵ��°汾�������ɰ汾����Ҫ�̶��̼���СΪ220K
	CodeZoneMaxSize = 220 * 1024;
	if(Def.StrLen(Firmware) > CodeZoneMaxSize)
		throw new Error("","Ŀǰ����ֻ֧�����" + CodeZoneMaxSize + "(����Loader)�Ĺ̼�")
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
	
	//���Ĺ̼�MAC
	var mac11 = Def.StrRight( Alg.Encrypt("SM4-CBC", SK, "00000000000000000000000000000000", Firmware, true), 16);		
	var CipherFirmware = Alg.Encrypt("SM4-ECB", SK, "00000000000000000000000000000000", Firmware, false)
	//���Ĺ̼�MAC
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
	ULC_Send_APDU("80DA000000" + Def.StrLen2Hex(switchInfo + signdata, 2) + switchInfo + signdata);
	
	ret = ULC_Send_APDU("E0B4011C022000");
	sm2_n = ret;
	var Itrus = Mgr.CreateInstance("LgnAlg.LgnItrus");
	Itrus.sm2_pubkey_import(sm2_n);
	var encryptSK = Itrus.sm2_encrypt(SK);
	Debug.writeln("encryptSK:" + encryptSK);
	//����SK
	ULC_Send_APDU("0020001C00" + Def.StrLen2Hex(encryptSK, 2) + encryptSK);
	
	//
	var startoffset = 0;
	/*
	//֧��bitmap��ʽ����֧��ȡ�ϵ�
	var breakpoint_flag = 0;
	if(1 == USE_BREAK_POINT)
	{
		//��ȡ�̼�������ʼλ�ã�֧�ֶϵ�����
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
		
	//��ʼ���������̼�
	Ins.InsParam("DEBUGER") = null;
	for(offset = startoffset; offset + PacketSize < FLen; offset += PacketSize)
	{
		try
		{
			{
				var send_Data = Def.StrMid(CipherFirmware, offset, PacketSize);
				var crc = crc16c(send_Data,0);
				ULC_Send_APDU("00D0000000" + Def.Int2Hex2(PacketSize+6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2));
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
	ULC_Send_APDU("00D0000000" + Def.Int2Hex2(FLen - offset + 6) + Def.Int2Hex(offset, 4) + send_Data + Def.Int2Hex(crc,2));
	Ins.InsParam("DEBUGER") = Debug;
	
	ULC_Send_APDU("80c4000000");
	
	Debug.writeln("========�ȴ�KEY������ɺ�����...");
	Ins.ExecuteSingleEx("CMD[DELAY:0]");
	// ѡ�������
	Ins.ExecuteSingleEx("CMD[READER:SR_WinReaderU.dll||cdrom||4]");
	// ���ÿ�Ƭ���ͣ�BASE��CARD, PBOC, PSAM, PK��Ĭ��ΪPBOC
	Ins.InsVar("CARDTYPE") = "BASE";
	Ins.ExecuteSingleEx("CMD[ATR]");
	
	ULC_Send_APDU("00A4000002DF20");
	var tempstr = ""
	var strlen;
	
	//Ins.ExecuteSingleEx("CMD[ENCOMM:11223344556677889900112233445577]");
	var cosVer = ULC_Send_APDU("F0F6020000");
	Debug.writeln("��COS Version: " + Def.Str2Hex(cosVer));
	if(1 == UpdateTypeFlag)
	{
		cosVer = ULC_Send_APDU("F0F6030000");
		Debug.writeln("Nordic Version: " + Def.Str2Hex(cosVer));
	}
	
	if(2 == UpdateTypeFlag)
	{
		//������չ324�������Ƿ���ȷ
		cosVer = ULC_Send_APDU("FCD5261805FCD5100000");
		cosVer = Def.StrLeft(cosVer, Def.StrLen(cosVer)-2);
		Debug.writeln("��չ324 Version: " + Def.Str2Hex(cosVer));
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
	
	Debug.writeln("���Խ���");
}