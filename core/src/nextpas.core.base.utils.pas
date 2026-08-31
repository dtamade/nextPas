unit nextpas.core.base.utils;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.base;

{** 对象生命周期工具 *}
procedure FreeAndNil(var AObj); inline;
procedure SafeFree(var AObj); inline;

{** 内存操作（System 内建的包装，确保接口一致） *}
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
function CompareBytesOrdered(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
function CompareBytesIgnoreCase(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
function HashFNV1aLower(A: Pointer; ALen: SizeUInt): UInt32; inline;

{** SizeUInt 边界与溢出 guard *}
function TryAddSizeUInt(const ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean; inline;
function CheckedAddSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
function TryMulSizeUInt(const ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean; inline;
function CheckedMulSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
procedure CheckSizeRange(const AOffset, ALength, ASize: SizeUInt);

{** 字节序转换（host/network）— 单源实现，供 system 门面 re-export *}
function HTonN(AValue: Word): Word; overload; inline;
function HTonN(AValue: LongWord): LongWord; overload; inline;
function NToHs(AValue: Word): Word; overload; inline;
function NToHs(AValue: LongWord): LongWord; overload; inline;

{** 接口查询 *}
procedure ClearOutInterface(out AIntf); inline;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;

implementation

uses
  nextpas.core.simd.vec;

procedure FreeAndNil(var AObj);
var LTemp: TObject;
begin
  LTemp := TObject(AObj);
  Pointer(AObj) := nil;
  LTemp.Free;
end;

procedure SafeFree(var AObj); inline;
begin
  FreeAndNil(AObj);
end;

procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
begin
  if ASize = 0 then
    Exit;
  if ADst = nil then
    raise EArgumentNil.Create('ZeroMem: destination is nil');
  FillChar(ADst^, ASize, 0);
end;

procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte); inline;
begin
  if ASize = 0 then
    Exit;
  if ADst = nil then
    raise EArgumentNil.Create('FillMem: destination is nil');
  FillChar(ADst^, ASize, AValue);
end;

procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
begin
  if ASize = 0 then
    Exit;
  if ADst = nil then
    raise EArgumentNil.Create('CopyMem: destination is nil');
  if ASrc = nil then
    raise EArgumentNil.Create('CopyMem: source is nil');
  Move(ASrc^, ADst^, ASize);
end;

function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
begin
  if ASize = 0 then Exit(True);
  if (A = nil) or (B = nil) then Exit(False);
  Result := System.CompareByte(A^, B^, ASize) = 0;
end;

function CompareBytesOrdered(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
var
  N: SizeUInt;
  C: SizeInt;
begin
  if (ALen > 0) and (A = nil) then
    raise EArgumentNil.Create('CompareBytesOrdered: A is nil');
  if (BLen > 0) and (B = nil) then
    raise EArgumentNil.Create('CompareBytesOrdered: B is nil');
  N := ALen;
  if BLen < N then
    N := BLen;
  if N > 0 then
  begin
    C := System.CompareByte(A^, B^, SizeInt(N));
    if C < 0 then Exit(-1);
    if C > 0 then Exit(1);
  end;
  if ALen < BLen then Exit(-1);
  if ALen > BLen then Exit(1);
  Result := 0;
end;

function CompareBytesIgnoreCase(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
var
  N, LPos, I: SizeUInt;
  PA, PB: PByte;
  LTmpA, LTmpB: array[0..31] of Byte;
  LB1, LB2: Byte;
begin
  if (ALen > 0) and (A = nil) then
    raise EArgumentNil.Create('CompareBytesIgnoreCase: A is nil');
  if (BLen > 0) and (B = nil) then
    raise EArgumentNil.Create('CompareBytesIgnoreCase: B is nil');
  N := ALen;
  if BLen < N then
    N := BLen;
  PA := PByte(A);
  PB := PByte(B);
  LPos := 0;
  while LPos + SizeUInt(VecWidth) <= N do
  begin
    for I := 0 to SizeUInt(VecWidth) - 1 do
    begin
      LB1 := PA[LPos + I];
      if (LB1 >= 65) and (LB1 <= 90) then
        LB1 := LB1 or $20;
      LTmpA[I] := LB1;
      LB2 := PB[LPos + I];
      if (LB2 >= 65) and (LB2 <= 90) then
        LB2 := LB2 or $20;
      LTmpB[I] := LB2;
    end;
    if VecCmpEq2(@LTmpA[0], @LTmpB[0]) <> TVecMask(not TVecMask(0)) then
    begin
      for I := 0 to SizeUInt(VecWidth) - 1 do
      begin
        if LTmpA[I] < LTmpB[I] then Exit(-1);
        if LTmpA[I] > LTmpB[I] then Exit(1);
      end;
    end;
    Inc(LPos, SizeUInt(VecWidth));
  end;
  while LPos < N do
  begin
    LB1 := PA[LPos];
    if (LB1 >= 65) and (LB1 <= 90) then
      LB1 := LB1 or $20;
    LB2 := PB[LPos];
    if (LB2 >= 65) and (LB2 <= 90) then
      LB2 := LB2 or $20;
    if LB1 < LB2 then Exit(-1);
    if LB1 > LB2 then Exit(1);
    Inc(LPos);
  end;
  if ALen < BLen then Exit(-1);
  if ALen > BLen then Exit(1);
  Result := 0;
end;

function HashFNV1aLower(A: Pointer; ALen: SizeUInt): UInt32; inline;
var
  P: PByte;
  H: UInt32;
  LPos, I: SizeUInt;
  LTmp: array[0..31] of Byte;
  LB: Byte;
begin
  // perf: scalar xor*prime with LowerTable; hot for short keys, kept inline for
  // inlining into maps/dicts. Future SIMD: 16/32-byte vector LowerTable lookup
  // via PSHUFB/AVX2 gather + parallel FNV reduction; not applied for portability
  // and because typical ALen < 32 makes scalar competitive.
  if (ALen > 0) and (A = nil) then
    raise EArgumentNil.Create('HashFNV1aLower: A is nil');
  H := 2166136261;
  P := PByte(A);
  LPos := 0;
  while LPos + SizeUInt(VecWidth) <= ALen do
  begin
    for I := 0 to SizeUInt(VecWidth) - 1 do
    begin
      LB := P[LPos + I];
      if (LB >= 65) and (LB <= 90) then
        LB := LB or $20;
      LTmp[I] := LB;
    end;
    for I := 0 to SizeUInt(VecWidth) - 1 do
    begin
      H := H xor UInt32(LTmp[I]);
      H := H * 16777619;
    end;
    Inc(LPos, SizeUInt(VecWidth));
  end;
  while LPos < ALen do
  begin
    LB := P[LPos];
    if (LB >= 65) and (LB <= 90) then
      LB := LB or $20;
    H := H xor UInt32(LB);
    H := H * 16777619;
    Inc(LPos);
  end;
  Result := H;
end;

function TryAddSizeUInt(const ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean; inline;
begin
  Result := ALeft <= MAX_SIZE_UINT - ARight;
  if Result then
    ASum := ALeft + ARight;
end;

function CheckedAddSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
begin
  Result := 0;
  if not TryAddSizeUInt(ALeft, ARight, Result) then
    raise EOverflow.Create('CheckedAddSizeUInt: size overflow');
end;

function TryMulSizeUInt(const ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean; inline;
begin
  if (ALeft = 0) or (ARight = 0) then
  begin
    AProduct := 0;
    Exit(True);
  end;

  Result := ALeft <= MAX_SIZE_UINT div ARight;
  if Result then
    AProduct := ALeft * ARight;
end;

function CheckedMulSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
begin
  Result := 0;
  if not TryMulSizeUInt(ALeft, ARight, Result) then
    raise EOverflow.Create('CheckedMulSizeUInt: size overflow');
end;

procedure CheckSizeRange(const AOffset, ALength, ASize: SizeUInt);
begin
  if AOffset > ASize then
    raise EOutOfRange.CreateFmt(
      'CheckSizeRange: offset %d + length %d > size %d',
      [AOffset, ALength, ASize]);
  if ALength > ASize - AOffset then
    raise EOutOfRange.CreateFmt(
      'CheckSizeRange: offset %d + length %d > size %d',
      [AOffset, ALength, ASize]);
end;

procedure ClearOutInterface(out AIntf);
begin
  IInterface(AIntf) := nil;
end;

function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then
  begin
    ClearOutInterface(AIntf);
    Exit(False);
  end;
  Result := AInstance.GetInterface(AIID, AIntf);
  if not Result then
    ClearOutInterface(AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;
begin
  if AInstance = nil then
  begin
    ClearOutInterface(AIntf);
    Exit(False);
  end;
  Result := AInstance.QueryInterface(AIID, AIntf) = S_OK;
  if not Result then
    ClearOutInterface(AIntf);
end;

function HTonN(AValue: Word): Word;
begin
  {$IFDEF ENDIAN_LITTLE}
  Result := Swap(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function HTonN(AValue: LongWord): LongWord;
begin
  {$IFDEF ENDIAN_LITTLE}
  Result := Swap(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function NToHs(AValue: Word): Word;
begin
  {$IFDEF ENDIAN_LITTLE}
  Result := Swap(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function NToHs(AValue: LongWord): LongWord;
begin
  {$IFDEF ENDIAN_LITTLE}
  Result := Swap(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

end.
