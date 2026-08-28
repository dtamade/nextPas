unit nextpas.core.sevenz.bcj.armt;

{**
 * nextpas.core.sevenz.bcj.armt - BCJ ARM Thumb 分支地址转换过滤器
 *
 * 移植 xz simple/armthumb.c：Thumb-2 32 位 BL 指令由两条 16 位半字组成，
 *   模式 0xF0xx 0xF8xx，11+11 位拼接 <<1 后与 pc+4 加减换算。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

procedure SevenZBcjArmtConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);

implementation

procedure SevenZBcjArmtConvert(var AData: TBytes; AStartOffset: UInt32;
  AEncode: Boolean);
var
  LSize: SizeInt;
  LI: SizeInt;
  LSrc, LDest, LPC: UInt32;
begin
  if Length(AData) < 4 then Exit;
  LSize := Length(AData) - 4;
  LI := 0;
  while LI <= LSize do
  begin
    if ((AData[LI + 1] and $F8) = $F0) and ((AData[LI + 3] and $F8) = $F8) then
    begin
      {$PUSH}{$Q-}{$R-}
      LSrc := ((UInt32(AData[LI + 1]) and 7) shl 19) or
              (UInt32(AData[LI]) shl 11) or
              ((UInt32(AData[LI + 3]) and 7) shl 8) or
              UInt32(AData[LI + 2]);
      LSrc := LSrc shl 1;
      LPC := AStartOffset + UInt32(LI) + 4;
      if AEncode then
        LDest := LPC + LSrc
      else
        LDest := LSrc - LPC;
      LDest := LDest shr 1;
      AData[LI + 1] := $F0 or Byte((LDest shr 19) and $7);
      AData[LI] := Byte((LDest shr 11) and $FF);
      AData[LI + 3] := $F8 or Byte((LDest shr 8) and $7);
      AData[LI + 2] := Byte(LDest and $FF);
      {$POP}
      Inc(LI, 4);
    end
    else
      Inc(LI, 2);
  end;
end;

end.
