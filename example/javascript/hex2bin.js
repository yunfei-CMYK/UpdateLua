/*
:0B00A00080FA92006F3600C3A00076CB
":"����     ������¼�Ŀ�ʼ			
�����ַ�    ������¼�ĳ���			0B
�ĸ��ַ�    �������ݵĵ�ַ(���)	00A0
�����ַ�    ������¼������;			00
                 0 ���ݼ�¼ 
				 1 ��¼�ļ����� 
				 2 ��չ�ε�ַ��¼ 
				 3 ��ʼ�ε�ַ��¼ 
				 4 ��չ���Ե�ַ��¼ 
				 5 ��ʼ���Ե�ַ��¼
n���ַ�     ���������ݼ�¼			80 FA 92 00 6F 36 00 C3 A0 00 76
�����λ    У��ͼ��,������ǰ�����е����ݺ�Ϊ0	CB

/IMPORTANT/
���һ������,����д���������.
:00000001FF
*/
function Hex2Bin(HexFileName,BinFileName,FillCode)
{
	var HexFile = Mgr.CreateInstance("LgnPacket.LgnFile");
	var BinFile = Mgr.CreateInstance("LgnPacket.LgnFile");
	var Def = Mgr.DefaultObject;
//	Debug.writeln(HexFile.Help("Read"));
//	return;
	Debug.writeln("File to open :" + HexFileName);
	HexFile.Open(HexFileName);
	Debug.writeln("File to open :" + BinFileName);
	BinFile.Open(BinFileName);
	BinFile.Parameter("SIZE")=0;
//	for(var i=0;i<0x10000;++i)
//	{
//		BinFile.Write(Def.Int2Hex1(FillCode));
//	}
var extendAddr = 0;
var offsetAddr = 0;
try
{
	while(1)
	{
		var HexHead = HexFile.Read(9,1);
//		Debug.writeln(HexHead);//debug
		if(HexHead.length < 9)
		{
			Debug.writeln("Hex file Format Error.0");
			throw "Error";
		}
		if(HexHead.substr(0,1) != ":")
		{
			Debug.writeln("Hex file Format Error.1");
			throw "Error";
		}
		var HexLen = Def.Str2Int(HexHead.substr(1,2),16);
		var HexAddr = Def.Str2Int(HexHead.substr(3,4),16);
		var HexFlag = Def.Str2Int(HexHead.substr(7,2),16);
		
		if (0 != extendAddr)
			HexAddr += extendAddr << 16;
		else
			HexAddr += offsetAddr << 4;
		if(HexLen != 0x00)
		{
			var HexData = HexFile.Read(HexLen*2,1);
			if(HexData.length < HexLen*2)
			{
				Debug.writeln("Hex file Format Error.2");
				throw "Error";
			}
			if(0x04 == HexFlag)
			{
				extendAddr = Def.Str2Int(HexData.substr(0,4),16);
				offsetAddr = 0;
			}
			else if(0x02 == HexFlag)
			{
				offsetAddr = Def.Str2Int(HexData.substr(0,4),16);
				extendAddr = 0;
			}
			else if(0x00 == HexFlag)
			{
				BinFile.Parameter("POINTER")=HexAddr;
				BinFile.Write(HexData);
			}
		}
		var HexTail = HexFile.Read(4,1);//CheckSum,0x0D,0x0A
		if(HexTail.length < 4)
		{
			Debug.writeln("Hex file Format Error.3");
			throw "Error";
		}
		if(HexFlag == 0x01)
			break;
	}
	HexFile.Close();
	BinFile.Close();
}

catch(e)
{
	HexFile.Close();
	BinFile.Close();
	Debug.writeln(e);
}
	return;
}
