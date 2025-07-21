/*
:0B00A00080FA92006F3600C3A00076CB
":"符号     表明记录的开始			
两个字符    表明记录的长度			0B
四个字符    表明数据的地址(大端)	00A0
两个字符    表明记录的类型;			00
                 0 数据记录 
				 1 记录文件结束 
				 2 扩展段地址记录 
				 3 开始段地址记录 
				 4 扩展线性地址记录 
				 5 开始线性地址记录
n个字符     真正的数据记录			80 FA 92 00 6F 36 00 C3 A0 00 76
最后两位    校验和检查,它加上前面所有的数据和为0	CB

/IMPORTANT/
最后一行特殊,总是写成这个样子.
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
