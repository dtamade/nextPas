unit nextpas.core.sevenz.bcj.utils;

{**
 * nextpas.core.sevenz.bcj.utils - BCJ 共用小端/大端与 PC 加减 helper 单源
 *
 * 抽取在 bcj.arm64 / bcj.riscv / bcj2 / filters 等处重复的
 * ReadLE32/WriteLE32/ReadBE32/WriteBE32 与 AddPc/SubPc，
 * 供 8 个 bcj.* 单元复用，消除 3 处以上重复。
 * 全部 inline、无 IFDEF、双编译器一致语义（Q-/R- 溢出环绕）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function ReadLE32(const AData: TBytes; AOff: SizeInt): UInt32; inline;
procedure WriteLE32(var AData: TBytes; AOff: SizeInt; AVal: UInt32); inline;
function ReadBE32(const AData: TBytes; AOff: SizeInt): UInt32; inline;
procedure WriteBE32(var AData: TBytes; AOff: SizeInt; AVal: UInt32); inline;
function GetBE32(const AP: PByte): UInt32; inline;
procedure SetLE32(const AP: PByte; AVal: UInt32); inline;
function AddPc(AValue, APc: UInt32): UInt32; inline;
function SubPc(AValue, APc: UInt32): UInt32; inline;

implementation

function ReadLE32(const AData: TBytes; AOff: SizeInt): UInt32; inline;
begin
  {$PUSH}{$Q-}{$R-}
  Result := UInt32(AData[AOff]) or (UInt32(AData[AOff + 1]) shl 8) or
    (UInt32(AData[AOff + 2]) shl 16) or (UInt32(AData[AOff + 3]) shl 24);
  {$POP}
end;

procedure WriteLE32(var AData: TBytes; AOff: SizeInt; AVal: UInt32); inline;
begin
  AData[AOff] := Byte(AVal and $FF);
  AData[AOff + 1] := Byte((AVal shr 8) and $FF);
  AData[AOff + 2] := Byte((AVal shr 16) and $FF);
  AData[AOff + 3] := Byte((AVal shr 24) and $FF);
end;

function ReadBE32(const AData: TBytes; AOff: SizeInt): UInt32; inline;
begin
  {$PUSH}{$Q-}{$R-}
  Result := (UInt32(AData[AOff]) shl 24) or (UInt32(AData[AOff + 1]) shl 16) or
    (UInt32(AData[AOff + 2]) shl 8) or UInt32(AData[AOff + 3]);
  {$POP}
end;

procedure WriteBE32(var AData: TBytes; AOff: SizeInt; AVal: UInt32); inline;
begin
  AData[AOff] := Byte((AVal shr 24) and $FF);
  AData[AOff + 1] := Byte((AVal shr 16) and $FF);
  AData[AOff + 2] := Byte((AVal shr 8) and $FF);
  AData[AOff + 3] := Byte(AVal and $FF);
end;

function GetBE32(const AP: PByte): UInt32; inline;
begin
  {$PUSH}{$Q-}{$R-}
  Result := (UInt32(AP[0]) shl 24) or (UInt32(AP[1]) shl 16) or
    (UInt32(AP[2]) shl 8) or UInt32(AP[3]);
  {$POP}
end;

procedure SetLE32(const AP: PByte; AVal: UInt32); inline;
begin
  AP[0] := Byte(AVal);
  AP[1] := Byte(AVal shr 8);
  AP[2] := Byte(AVal shr 16);
  AP[3] := Byte(AVal shr 24);
end;

function AddPc(AValue, APc: UInt32): UInt32; inline;
begin
  {$PUSH}{$Q-}{$R-}
  Result := AValue + APc;
  {$POP}
end;

function SubPc(AValue, APc: UInt32): UInt32; inline;
begin
  {$PUSH}{$Q-}{$R-}
  Result := AValue - APc;
  {$POP}
end;

end.
