unit nextpas.core.hash.shake128;

{$mode objfpc}{$H+}

{ nextpas.core.hash.shake128 — SHAKE128 XOF（FIPS 202 / Keccak-f[1600]）。
  速率 168 字节，域分隔 0x1F。Write 吸收；首次 Read 填充并挤压，
  之后只允许再 Read。 }

interface

uses
  nextpas.core.base;

const
  SHAKE128_RATE = 168;

type
  TSHAKE128 = class
  private
    FA: array[0..24] of UInt64;
    FBuf: array[0..167] of Byte;
    FBufLen: Integer;
    FOutBuf: array[0..167] of Byte;
    FOutPos: Integer;
    FSqueezing: Boolean;
    procedure Permute;
    procedure XorIn(ASrc: PByte);
    procedure CopyOut(ADst: PByte);
    procedure FinalizeAbsorb;
  public
    constructor Create; overload;
    constructor Create(const ASeed: TBytes); overload;
    procedure Write(const ABuf; const ACount: SizeUInt);
    procedure Read(out ADst; ACount: SizeUInt);
  end;

function NewSHAKE128: TSHAKE128;
function SHAKE128Of(const ABuf; ALen: SizeUInt; AOutLen: SizeUInt): TBytes;

implementation

uses
  nextpas.core.errors;

const
  cKeccakRC: array[0..23] of UInt64 = (
    $0000000000000001, $0000000000008082, UInt64($800000000000808A), UInt64($8000000080008000),
    $000000000000808B, $0000000080000001, UInt64($8000000080008081), UInt64($8000000000008009),
    $000000000000008A, $0000000000000088, $0000000080008009, $000000008000000A,
    $000000008000808B, UInt64($800000000000008B), UInt64($8000000000008089), UInt64($8000000000008003),
    UInt64($8000000000008002), UInt64($8000000000000080), $000000000000800A, UInt64($800000008000000A),
    UInt64($8000000080008081), UInt64($8000000000008080), $0000000080000001, UInt64($8000000080008008));

  cKeccakRot: array[0..4, 0..4] of Byte = (
    (0, 36, 3, 41, 18),
    (1, 44, 10, 45, 2),
    (62, 6, 43, 15, 61),
    (28, 55, 25, 21, 56),
    (27, 20, 39, 8, 14));

function Rotl64(const AValue: UInt64; AShift: Integer): UInt64;
begin
  if AShift = 0 then
    Result := AValue
  else
    Result := (AValue shl AShift) or (AValue shr (64 - AShift));
end;

constructor TSHAKE128.Create;
begin
  inherited Create;
  FillChar(FA[0], SizeOf(FA), 0);
  FillChar(FBuf[0], SizeOf(FBuf), 0);
  FBufLen := 0;
  FOutPos := SHAKE128_RATE;
  FSqueezing := False;
end;

constructor TSHAKE128.Create(const ASeed: TBytes);
begin
  Create;
  if Length(ASeed) > 0 then
    Write(ASeed[0], Length(ASeed));
end;

procedure TSHAKE128.XorIn(ASrc: PByte);
var
  I: Integer;
  L: UInt64;
begin
  for I := 0 to 20 do
  begin
    L := UInt64(ASrc[I * 8])
      or (UInt64(ASrc[I * 8 + 1]) shl 8)
      or (UInt64(ASrc[I * 8 + 2]) shl 16)
      or (UInt64(ASrc[I * 8 + 3]) shl 24)
      or (UInt64(ASrc[I * 8 + 4]) shl 32)
      or (UInt64(ASrc[I * 8 + 5]) shl 40)
      or (UInt64(ASrc[I * 8 + 6]) shl 48)
      or (UInt64(ASrc[I * 8 + 7]) shl 56);
    FA[I] := FA[I] xor L;
  end;
end;

procedure TSHAKE128.CopyOut(ADst: PByte);
var
  I: Integer;
  L: UInt64;
begin
  for I := 0 to 20 do
  begin
    L := FA[I];
    ADst[I * 8] := Byte(L);
    ADst[I * 8 + 1] := Byte(L shr 8);
    ADst[I * 8 + 2] := Byte(L shr 16);
    ADst[I * 8 + 3] := Byte(L shr 24);
    ADst[I * 8 + 4] := Byte(L shr 32);
    ADst[I * 8 + 5] := Byte(L shr 40);
    ADst[I * 8 + 6] := Byte(L shr 48);
    ADst[I * 8 + 7] := Byte(L shr 56);
  end;
end;

procedure TSHAKE128.Permute;
var
  LC, LD: array[0..4] of UInt64;
  LB: array[0..24] of UInt64;
  LR, LX, LY, LX2, LY2: Integer;
begin
  for LR := 0 to 23 do
  begin
    for LX := 0 to 4 do
      LC[LX] := FA[LX] xor FA[LX + 5] xor FA[LX + 10]
        xor FA[LX + 15] xor FA[LX + 20];
    for LX := 0 to 4 do
      LD[LX] := LC[(LX + 4) mod 5] xor Rotl64(LC[(LX + 1) mod 5], 1);
    for LX := 0 to 4 do
      for LY := 0 to 4 do
        FA[LX + 5 * LY] := FA[LX + 5 * LY] xor LD[LX];
    for LX := 0 to 4 do
      for LY := 0 to 4 do
      begin
        LX2 := LY;
        LY2 := (2 * LX + 3 * LY) mod 5;
        LB[LX2 + 5 * LY2] := Rotl64(FA[LX + 5 * LY], cKeccakRot[LX, LY]);
      end;
    for LX := 0 to 4 do
      for LY := 0 to 4 do
        FA[LX + 5 * LY] := LB[LX + 5 * LY]
          xor ((not LB[(LX + 1) mod 5 + 5 * LY])
            and LB[(LX + 2) mod 5 + 5 * LY]);
    FA[0] := FA[0] xor cKeccakRC[LR];
  end;
end;

procedure TSHAKE128.Write(const ABuf; const ACount: SizeUInt);
var
  LSrc: PByte;
  LRemain, LTake: SizeUInt;
begin
  if FSqueezing then
    raise EInvalidOperationError.Create('SHAKE128.Write after Read');
  if ACount = 0 then
    Exit;
  LSrc := @ABuf;
  LRemain := ACount;
  while LRemain > 0 do
  begin
    LTake := SizeUInt(SHAKE128_RATE - FBufLen);
    if LTake > LRemain then
      LTake := LRemain;
    Move(LSrc^, FBuf[FBufLen], LTake);
    Inc(FBufLen, Integer(LTake));
    Inc(LSrc, LTake);
    Dec(LRemain, LTake);
    if FBufLen = SHAKE128_RATE then
    begin
      XorIn(@FBuf[0]);
      Permute;
      FillChar(FBuf[0], SizeOf(FBuf), 0);
      FBufLen := 0;
    end;
  end;
end;

procedure TSHAKE128.FinalizeAbsorb;
begin
  FBuf[FBufLen] := FBuf[FBufLen] xor $1F;
  FBuf[SHAKE128_RATE - 1] := FBuf[SHAKE128_RATE - 1] xor $80;
  XorIn(@FBuf[0]);
  Permute;
  CopyOut(@FOutBuf[0]);
  FOutPos := 0;
  FSqueezing := True;
end;

procedure TSHAKE128.Read(out ADst; ACount: SizeUInt);
var
  LDst: PByte;
  LRemain: SizeUInt;
  LTake: Integer;
begin
  if ACount = 0 then
    Exit;
  if not FSqueezing then
    FinalizeAbsorb;
  LDst := @ADst;
  LRemain := ACount;
  while LRemain > 0 do
  begin
    if FOutPos >= SHAKE128_RATE then
    begin
      Permute;
      CopyOut(@FOutBuf[0]);
      FOutPos := 0;
    end;
    LTake := SHAKE128_RATE - FOutPos;
    if SizeUInt(LTake) > LRemain then
      LTake := Integer(LRemain);
    Move(FOutBuf[FOutPos], LDst^, LTake);
    Inc(FOutPos, LTake);
    Inc(LDst, LTake);
    Dec(LRemain, LTake);
  end;
end;

function NewSHAKE128: TSHAKE128;
begin
  Result := TSHAKE128.Create;
end;

function SHAKE128Of(const ABuf; ALen: SizeUInt; AOutLen: SizeUInt): TBytes;
var
  S: TSHAKE128;
begin
  Result := nil;
  SetLength(Result, AOutLen);
  if AOutLen = 0 then
    Exit;
  S := TSHAKE128.Create;
  try
    if ALen > 0 then
      S.Write(ABuf, ALen);
    S.Read(Result[0], AOutLen);
  finally
    S.Free;
  end;
end;

end.
