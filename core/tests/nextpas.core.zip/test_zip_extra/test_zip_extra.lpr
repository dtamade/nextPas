program test_zip_extra;
{**
 * @desc extra 编解码对称性证明门：以最简确定性输入断言 Build* 与 Decode* 的
 *       往返单源一致性与 fail-closed 语义，锁定十五期 extra 内核的复用正确性。
 *
 * 覆盖：
 * 1. Local 往返：Descriptor×NeedsZip64×AES 强度(0..3)×真实方法两两组合，
 *    断言尺寸与 AES 元数据恢复一致，空配置产出空字节；
 * 2. Central 往返：NeedsSizes×NeedsOffset×AES 组合，顺序 Zip64→AES 固定；
 * 3. 空配置优化：无 Zip64/AES 时零长度；
 * 4. 恶意 extra：截断、重复 AES、错误长度、未知厂商均 EParseError；
 * 5. 顺序断言：Zip64 先于 AES，且 Zip64 体内 USize→CSize→Offset 顺序。
 *}
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.zip.aes,
  nextpas.core.zip.extra, nextpas.core.text.conv;

var
  T: TTestSuite;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMsg: string);
var LI: Integer;
begin
  Check(Length(AExpected)=Length(AActual), AMsg+': length '+IntToStr(Length(AExpected))+' vs '+IntToStr(Length(AActual)));
  for LI:=0 to High(AExpected) do Check(AExpected[LI]=AActual[LI], AMsg+': byte '+IntToStr(LI));
end;

function BytesOfStr(const S: string): TBytes;
begin SetLength(Result, Length(S)); if Length(S)>0 then Move(Pointer(S)^, Result[0], Length(S)); end;

procedure TestLocalRoundtrip;
var LUSize, LCSize: UInt64; LStrength: Byte; LMethod: Word; LDesc, LNeeds: Boolean; LExtra: TBytes;
    LOutUSize, LOutCSize: UInt64; LHasAes: Boolean; LVer, LVendor, LReal: Word; LStr: Byte;
    LI: Integer;
begin
  for LDesc in [False,True] do
    for LNeeds in [False,True] do
      for LStrength in [0,1,2,3] do
        for LI:=0 to 1 do
        begin
          if LI=0 then LMethod:=C_ZIP_METHOD_STORE else LMethod:=C_ZIP_METHOD_DEFLATE;
          LUSize:=12345; LCSize:=67890;
          LExtra:=BuildLocalExtra(LUSize, LCSize, LDesc, LNeeds, LStrength, LMethod);
          if (not LDesc and not LNeeds and (LStrength=0)) then Check(Length(LExtra)=0, 'empty local extra when no zip64/aes')
          else Check(Length(LExtra)>0, 'non-empty local extra when needed');
          LOutUSize:=UInt64($FFFFFFFF); LOutCSize:=UInt64($FFFFFFFF);
          DecodeLocalExtra(LExtra, LOutUSize, LOutCSize, LHasAes, LVer, LVendor, LReal, LStr);
          if LDesc then begin Check(LOutUSize=0, 'desc local USize zero'); Check(LOutCSize=0,'desc local CSize zero'); end
          else if LNeeds then begin Check(LOutUSize=LUSize,'local USize roundtrip'); Check(LOutCSize=LCSize,'local CSize roundtrip'); end
          else begin Check(LOutUSize=UInt64($FFFFFFFF),'local no zip64 keeps sentinel USize'); Check(LOutCSize=UInt64($FFFFFFFF),'local no zip64 keeps sentinel'); end;
          if LStrength=0 then Check(not LHasAes,'local no aes')
          else begin Check(LHasAes,'local has aes'); Check(LStr=LStrength,'local aes strength'); Check(LReal=LMethod,'local aes method'); Check(LVendor=C_WINZIP_AES_VENDOR_LE,'local aes vendor'); end;
        end;
  // sentinel preservation: when input not sentinel, decoder must not overwrite
  LExtra:=BuildLocalExtra(999, 888, False, True, 0, 0);
  LOutUSize:=555; LOutCSize:=666;
  DecodeLocalExtra(LExtra, LOutUSize, LOutCSize, LHasAes, LVer, LVendor, LReal, LStr);
  Check(LOutUSize=555,'local non-sentinel USize not overwritten');
  Check(LOutCSize=666,'local non-sentinel CSize not overwritten');
end;

procedure TestCentralRoundtrip;
var LUSize, LCSize, LOff: UInt64; LStrength: Byte; LMethod: Word; LNeedsSizes, LNeedsOff: Boolean; LExtra: TBytes;
    LOutUSize, LOutCSize, LOutOff: UInt64; LHasAes: Boolean; LVer, LVendor, LReal: Word; LStr: Byte;
begin
  for LNeedsSizes in [False,True] do
    for LNeedsOff in [False,True] do
      for LStrength in [0,3] do
      begin
        if LStrength=0 then LMethod:=0 else LMethod:=C_ZIP_METHOD_DEFLATE;
        LUSize:=11111; LCSize:=22222; LOff:=33333;
        LExtra:=BuildCentralExtra(LUSize, LCSize, LOff, LNeedsSizes, LNeedsOff, LStrength, LMethod);
        if (not LNeedsSizes and not LNeedsOff and (LStrength=0)) then Check(Length(LExtra)=0,'empty central extra')
        else Check(Length(LExtra)>0,'central non-empty');
        if LNeedsSizes then begin LOutUSize:=UInt64($FFFFFFFF); LOutCSize:=UInt64($FFFFFFFF); end else begin LOutUSize:=LUSize; LOutCSize:=LCSize; end;
        if LNeedsOff then LOutOff:=UInt64($FFFFFFFF) else LOutOff:=LOff;
        DecodeCentralExtra(LExtra, LOutUSize, LOutCSize, LOutOff, LHasAes, LVer, LVendor, LReal, LStr);
        if LNeedsSizes then begin Check(LOutUSize=LUSize,'central USize'); Check(LOutCSize=LCSize,'central CSize'); end
        else begin Check(LOutUSize=LUSize,'central USize preserved'); Check(LOutCSize=LCSize,'central CSize preserved'); end;
        if LNeedsOff then Check(LOutOff=LOff,'central offset') else Check(LOutOff=LOff,'central offset preserved');
        if LStrength=0 then Check(not LHasAes,'central no aes') else begin Check(LHasAes,'central has aes'); Check(LStr=LStrength,'central aes strength'); end;
      end;
end;

procedure TestExtraOrderAndWidths;
var LExtra: TBytes; LPos: Integer;
begin
  // Local: Zip64 before AES
  LExtra:=BuildLocalExtra(1,2, False, True, 3, C_ZIP_METHOD_DEFLATE);
  Check(Length(LExtra)=20+11,'local combined len');
  Check(LExtra[0]=Byte(C_ZIP64_EXTRA_ID and $FF),'local zip64 id lo'); Check(LExtra[1]=Byte(C_ZIP64_EXTRA_ID shr 8),'local zip64 id hi');
  Check(LExtra[20]=Byte(C_WINZIP_AES_EXTRA_ID and $FF),'local aes after zip64');
  // Central: body order USize->CSize->Offset
  LExtra:=BuildCentralExtra(10,20,30, True, True, 0, 0);
  Check(Length(LExtra)=4+24,'central 24 body');
  // body after header 4 bytes: USize 8, CSize 8, Offset 8
  LPos:=4;
  Check(LExtra[LPos]=10,'central USize lo'); // 10 little endian
  Check(LExtra[LPos+8]=20,'central CSize lo');
  Check(LExtra[LPos+16]=30,'central offset lo');
  // AES-only width
  LExtra:=BuildLocalExtra(0,0, False, False, 2, C_ZIP_METHOD_STORE);
  Check(Length(LExtra)=11,'local aes only len');
  LExtra:=BuildCentralExtra(0,0,0, False, False, 1, C_ZIP_METHOD_STORE);
  Check(Length(LExtra)=11,'central aes only len');
end;

procedure TestMalformed;
var LExtra: TBytes; LUSize, LCSize, LOff: UInt64; LHasAes: Boolean; LVer, LVendor, LReal: Word; LStr: Byte; LOk: Boolean;
begin
  // truncated extra: header claims 4-byte body but buffer has only 2
  SetLength(LExtra,6); LExtra[0]:=1; LExtra[1]:=0; LExtra[2]:=4; LExtra[3]:=0; LExtra[4]:=1; LExtra[5]:=2;
  LUSize:=UInt64($FFFFFFFF); LCSize:=UInt64($FFFFFFFF); LOff:=UInt64($FFFFFFFF);
  LOk:=False; try DecodeCentralExtra(LExtra, LUSize, LCSize, LOff, LHasAes, LVer, LVendor, LReal, LStr); except on E: EParseError do LOk:=True; end; Check(LOk,'truncated zip64 body not error (central)');
  SetLength(LExtra,6); LExtra[0]:=1; LExtra[1]:=0; LExtra[2]:=4; LExtra[3]:=0; LExtra[4]:=1; LExtra[5]:=2;
  LUSize:=UInt64($FFFFFFFF); LCSize:=UInt64($FFFFFFFF);
  LOk:=False; try DecodeLocalExtra(LExtra, LUSize, LCSize, LHasAes, LVer, LVendor, LReal, LStr); except on E: EParseError do LOk:=True; end; Check(LOk,'truncated zip64 body not error (local)');
  // duplicate AES
  LExtra:=BuildLocalExtra(1,2, False, False, 1, C_ZIP_METHOD_STORE);
  // append second AES extra
  SetLength(LExtra, Length(LExtra)+11);
  LExtra[11]:=Byte(C_WINZIP_AES_EXTRA_ID and $FF); LExtra[12]:=Byte(C_WINZIP_AES_EXTRA_ID shr 8); LExtra[13]:=7; LExtra[14]:=0;
  LUSize:=UInt64($FFFFFFFF); LCSize:=UInt64($FFFFFFFF);
  LOk:=False; try DecodeLocalExtra(LExtra, LUSize, LCSize, LHasAes, LVer, LVendor, LReal, LStr); except on E: EParseError do LOk:=True; end; Check(LOk,'duplicate AES not error');
  // bad aes vendor
  LExtra:=BuildLocalExtra(1,2, False, False, 1, C_ZIP_METHOD_STORE);
  LExtra[6]:=0; LExtra[7]:=0; // vendor overwrite to 0
  LUSize:=UInt64($FFFFFFFF); LCSize:=UInt64($FFFFFFFF);
  LOk:=False; try DecodeLocalExtra(LExtra, LUSize, LCSize, LHasAes, LVer, LVendor, LReal, LStr); except on E: EParseError do LOk:=True; end; Check(LOk,'bad aes vendor not error');
  // bad aes size (6 not 7)
  SetLength(LExtra,4+6); LExtra[0]:=Byte(C_WINZIP_AES_EXTRA_ID and $FF); LExtra[1]:=Byte(C_WINZIP_AES_EXTRA_ID shr 8); LExtra[2]:=6; LExtra[3]:=0;
  LUSize:=UInt64($FFFFFFFF); LCSize:=UInt64($FFFFFFFF);
  LOk:=False; try DecodeLocalExtra(LExtra, LUSize, LCSize, LHasAes, LVer, LVendor, LReal, LStr); except on E: EParseError do LOk:=True; end; Check(LOk,'bad aes size not error');
end;

procedure TestReserve;
var W: IZipWriter; R: IZipReader; LI: Integer; LAr1, LAr2, LData: TBytes; LOk: Boolean;
begin
  // 0 / 负值边界
  W:=NewZipWriter; W.Reserve(0); Check(W.EntryCount=0,'reserve 0 keeps empty');
  LOk:=False; try W.Reserve(-1); except on E: EArgumentError do LOk:=True; end; Check(LOk,'reserve negative raises');
  W.Reserve(10); W.AddEntry('a.txt', BytesOfStr('hi')); Check(W.EntryCount=1,'reserve 10 then add 1');
  // 预分配后字节级一致
  W:=NewZipWriter; W.Reserve(200);
  for LI:=0 to 199 do begin LData:=BytesOfStr('x'+IntToStr(LI)); W.AddEntry('f/'+IntToStr(LI)+'.bin', LData); end;
  LAr1:=W.Finish;
  W:=NewZipWriter;
  for LI:=0 to 199 do begin LData:=BytesOfStr('x'+IntToStr(LI)); W.AddEntry('f/'+IntToStr(LI)+'.bin', LData); end;
  LAr2:=W.Finish;
  Check(Length(LAr1)=Length(LAr2),'reserve byte-identical length');
  for LI:=0 to High(LAr1) do Check(LAr1[LI]=LAr2[LI],'reserve byte-identical body at '+IntToStr(LI));
  R:=NewZipReader(LAr1); Check(R.EntryCount=200,'reserve roundtrip count');
  // Reserve 小于已用容量应为 no-op
  W:=NewZipWriter; W.Reserve(5); for LI:=0 to 4 do W.AddEntry('a'+IntToStr(LI), nil); W.Reserve(3); Check(W.EntryCount=5,'reserve smaller than used is no-op'); W.AddEntry('b', nil); Check(W.EntryCount=6,'reserve smaller still allows growth');
  // Finish 后 Reserve 应 fail-closed
  W:=NewZipWriter; W.AddEntry('a', nil); W.Finish; LOk:=False; try W.Reserve(10); except on E: EInvalidOperationError do LOk:=True; end; Check(LOk,'reserve after finish raises');
end;

procedure TestZeroAllocConsistency;
var LBuf: array[0..63] of Byte; LLen: SizeUInt; LHeap: TBytes; LI, LJ: Integer;
begin
  for LI:=0 to 1 do
  begin
    LHeap:=BuildLocalExtra(123,456, LI=1, True, 2, C_ZIP_METHOD_DEFLATE);
    LLen:=EncodeLocalExtra(123,456, LI=1, True, 2, C_ZIP_METHOD_DEFLATE, @LBuf[0]);
    Check(LLen=SizeUInt(Length(LHeap)),'encode local len vs build');
    for LJ:=0 to Integer(LLen)-1 do Check(LHeap[LJ]=LBuf[LJ],'encode local byte '+IntToStr(LJ));
    LHeap:=BuildCentralExtra(10,20,30, True, True, 1, C_ZIP_METHOD_STORE);
    LLen:=EncodeCentralExtra(10,20,30, True, True, 1, C_ZIP_METHOD_STORE, @LBuf[0]);
    Check(LLen=SizeUInt(Length(LHeap)),'encode central len vs build');
    for LJ:=0 to Integer(LLen)-1 do Check(LHeap[LJ]=LBuf[LJ],'encode central byte '+IntToStr(LJ));
  end;
  // empty case
  LHeap:=BuildLocalExtra(0,0, False, False, 0, 0);
  Check(Length(LHeap)=0,'build local empty');
  LLen:=EncodeLocalExtra(0,0, False, False, 0, 0, @LBuf[0]);
  Check(LLen=0,'encode local empty');
end;

begin
  T:=TTestSuite.Create('nextpas.core.zip.extra');
  T.Test('Local roundtrip', @TestLocalRoundtrip);
  T.Test('Central roundtrip', @TestCentralRoundtrip);
  T.Test('Order and widths', @TestExtraOrderAndWidths);
  T.Test('Malformed fail-closed', @TestMalformed);
  T.Test('Reserve preallocation', @TestReserve);
  T.Test('Zero-alloc encode vs Build', @TestZeroAllocConsistency);
  if not T.Run then Halt(1);
end.
