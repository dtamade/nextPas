unit nextpas.core.base.utils;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.base;

{** 对象生命周期工具 *}
procedure FreeAndNil(var AObj);
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

{** 接口查询 *}
procedure ClearOutInterface(out AIntf);
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;

implementation

const
  LowerTable: array[0..255] of Byte = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
    64, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
    112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 91, 92, 93, 94, 95,
    96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
    112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127,
    128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
    144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
    160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,
    176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,
    192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,
    208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
    224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,
    240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255
  );

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
  N, I: SizeUInt;
  CA, CB: Byte;
  PA, PB: PByte;
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
  for I := 0 to N - 1 do
  begin
    CA := LowerTable[PA[I]];
    CB := LowerTable[PB[I]];
    if CA < CB then Exit(-1);
    if CA > CB then Exit(1);
  end;
  if ALen < BLen then Exit(-1);
  if ALen > BLen then Exit(1);
  Result := 0;
end;

function HashFNV1aLower(A: Pointer; ALen: SizeUInt): UInt32; inline;
var
  I: SizeUInt;
  P: PByte;
  H: UInt32;
begin
  if (ALen > 0) and (A = nil) then
    raise EArgumentNil.Create('HashFNV1aLower: A is nil');
  H := 2166136261;
  P := PByte(A);
  for I := 0 to ALen - 1 do
  begin
    H := H xor UInt32(LowerTable[P[I]]);
    H := H * 16777619;
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

end.
