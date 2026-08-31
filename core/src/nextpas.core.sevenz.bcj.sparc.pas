unit nextpas.core.sevenz.bcj.sparc;

{**
 * nextpas.core.sevenz.bcj.sparc - BCJ SPARC 分支地址转换过滤器
 *
 * 移植 xz simple/sparc.c 参考实现：4 字节对齐扫描，识别
 *   0x40xxxxxx (CALL) 与 0x7F C0xxxxxx (分支) 模式，32 位大端
 *   立即数 <<2 后与 pc 加减换算，目标回写时保留高位掩码。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.bcj.utils;

procedure SevenZBcjSparcConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

procedure SevenZBcjSparcConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LSrc, LDest, LPC: UInt32;
begin
  LSize := Length(AData) and not 3;
  LI := 0;
  while LI < LSize do
  begin
    if ((AData[LI] = $40) and ((AData[LI + 1] and $C0) = $00)) or
       ((AData[LI] = $7F) and ((AData[LI + 1] and $C0) = $C0)) then
    begin
      {$PUSH}{$Q-}{$R-}
      LSrc := (UInt32(AData[LI]) shl 24) or (UInt32(AData[LI + 1]) shl 16) or
              (UInt32(AData[LI + 2]) shl 8) or UInt32(AData[LI + 3]);
      LSrc := LSrc shl 2;
      LPC := AStartOffset + UInt32(LI);
      if AEncode then
        LDest := LPC + LSrc
      else
        LDest := LSrc - LPC;
      LDest := LDest shr 2;
      // 保留 CALL/BRANCH 高位标识：0x40000000 置位 + 符号扩展处理
      LDest := (((0 - ((LDest shr 22) and 1)) shl 22) and UInt32($3FFFFFFF)) or
               (LDest and $3FFFFF) or UInt32($40000000);
      AData[LI] := Byte((LDest shr 24) and $FF);
      AData[LI + 1] := Byte((LDest shr 16) and $FF);
      AData[LI + 2] := Byte((LDest shr 8) and $FF);
      AData[LI + 3] := Byte(LDest and $FF);
      {$POP}
    end;
    Inc(LI, 4);
  end;
end;

end.
