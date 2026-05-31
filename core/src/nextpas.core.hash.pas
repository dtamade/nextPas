unit nextpas.core.hash;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

type
  TSHA256Digest = array[0..31] of Byte;
  TSHA256State = record
  private
    FState: array[0..7] of UInt32;
    FBuffer: array[0..63] of Byte;
    FBufLen: UInt32;
    FTotalLen: UInt64;
    procedure ProcessBlock(const ABlock: Pointer);
  public
    procedure Init;
    procedure Update(const AData: Pointer; ALen: SizeUInt);
    procedure UpdateStr(const AStr: string);
    procedure UpdateView(const AView: TStringView);
    function Finalize: TSHA256Digest;
  end;

  TMD5Digest = array[0..15] of Byte;
  TMD5State = record
  private
    FState: array[0..3] of UInt32;
    FBuffer: array[0..63] of Byte;
    FBufLen: UInt32;
    FTotalLen: UInt64;
    procedure ProcessBlock(const ABlock: Pointer);
  public
    procedure Init;
    procedure Update(const AData: Pointer; ALen: SizeUInt);
    procedure UpdateStr(const AStr: string);
    function Finalize: TMD5Digest;
  end;

  TCRC32State = record
  private
    FValue: UInt32;
  public
    procedure Init;
    procedure Update(const AData: Pointer; ALen: SizeUInt);
    procedure UpdateStr(const AStr: string);
    function Finalize: UInt32;
  end;

// One-shot convenience functions
function SHA256(const AData: Pointer; ALen: SizeUInt): TSHA256Digest;
function SHA256Str(const AStr: string): TSHA256Digest;
function SHA256Hex(const AData: Pointer; ALen: SizeUInt): string;
function SHA256StrHex(const AStr: string): string;

function MD5(const AData: Pointer; ALen: SizeUInt): TMD5Digest;
function MD5Str(const AStr: string): TMD5Digest;
function MD5Hex(const AData: Pointer; ALen: SizeUInt): string;
function MD5StrHex(const AStr: string): string;

function CRC32(const AData: Pointer; ALen: SizeUInt): UInt32;
function CRC32Str(const AStr: string): UInt32;

function DigestToHex(const ADigest; ALen: Int32): string;

implementation

uses
  nextpas.core.text.conv;

const
  SHA256_K: array[0..63] of UInt32 = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
    $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3,
    $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
    $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7,
    $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
    $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
    $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
    $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208,
    $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

{$PUSH}{$Q-}{$R-}

function ROR32(AVal: UInt32; AShift: Byte): UInt32; inline;
begin
  Result := (AVal shr AShift) or (AVal shl (32 - AShift));
end;

function BE32(const P: PByte): UInt32; inline;
begin
  Result := (UInt32(P[0]) shl 24) or (UInt32(P[1]) shl 16) or
            (UInt32(P[2]) shl 8) or UInt32(P[3]);
end;

procedure PutBE32(P: PByte; V: UInt32); inline;
begin
  P[0] := Byte(V shr 24);
  P[1] := Byte(V shr 16);
  P[2] := Byte(V shr 8);
  P[3] := Byte(V);
end;

procedure PutBE64(P: PByte; V: UInt64); inline;
begin
  PutBE32(P, UInt32(V shr 32));
  PutBE32(P + 4, UInt32(V));
end;

{ TSHA256State }

procedure TSHA256State.Init;
begin
  FState[0] := $6a09e667; FState[1] := $bb67ae85;
  FState[2] := $3c6ef372; FState[3] := $a54ff53a;
  FState[4] := $510e527f; FState[5] := $9b05688c;
  FState[6] := $1f83d9ab; FState[7] := $5be0cd19;
  FBufLen := 0;
  FTotalLen := 0;
end;

procedure TSHA256State.ProcessBlock(const ABlock: Pointer);
var
  W: array[0..63] of UInt32;
  A, B, C, D, E, F, G, H: UInt32;
  S0, S1, Ch, Maj, T1, T2: UInt32;
  LI: Int32;
  LP: PByte;
begin
  LP := PByte(ABlock);
  for LI := 0 to 15 do
    W[LI] := BE32(LP + LI * 4);
  for LI := 16 to 63 do
  begin
    S0 := ROR32(W[LI-15], 7) xor ROR32(W[LI-15], 18) xor (W[LI-15] shr 3);
    S1 := ROR32(W[LI-2], 17) xor ROR32(W[LI-2], 19) xor (W[LI-2] shr 10);
    W[LI] := W[LI-16] + S0 + W[LI-7] + S1;
  end;

  A := FState[0]; B := FState[1]; C := FState[2]; D := FState[3];
  E := FState[4]; F := FState[5]; G := FState[6]; H := FState[7];

  for LI := 0 to 63 do
  begin
    S1 := ROR32(E, 6) xor ROR32(E, 11) xor ROR32(E, 25);
    Ch := (E and F) xor ((not E) and G);
    T1 := H + S1 + Ch + SHA256_K[LI] + W[LI];
    S0 := ROR32(A, 2) xor ROR32(A, 13) xor ROR32(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    T2 := S0 + Maj;
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;

  FState[0] += A; FState[1] += B; FState[2] += C; FState[3] += D;
  FState[4] += E; FState[5] += F; FState[6] += G; FState[7] += H;
end;

procedure TSHA256State.Update(const AData: Pointer; ALen: SizeUInt);
var
  LP: PByte;
  LRemaining, LCopy: SizeUInt;
begin
  if (ALen = 0) or (AData = nil) then Exit;
  LP := PByte(AData);
  FTotalLen += ALen;
  if FBufLen > 0 then
  begin
    LCopy := 64 - FBufLen;
    if LCopy > ALen then LCopy := ALen;
    Move(LP^, FBuffer[FBufLen], LCopy);
    Inc(FBufLen, LCopy);
    Inc(LP, LCopy);
    Dec(ALen, LCopy);
    if FBufLen = 64 then
    begin
      ProcessBlock(@FBuffer[0]);
      FBufLen := 0;
    end;
  end;
  while ALen >= 64 do
  begin
    ProcessBlock(LP);
    Inc(LP, 64);
    Dec(ALen, 64);
  end;
  if ALen > 0 then
  begin
    Move(LP^, FBuffer[0], ALen);
    FBufLen := ALen;
  end;
end;

procedure TSHA256State.UpdateStr(const AStr: string);
begin
  if Length(AStr) > 0 then
    Update(@AStr[1], Length(AStr));
end;

procedure TSHA256State.UpdateView(const AView: TStringView);
begin
  if AView.Len > 0 then
    Update(AView.Data, AView.Len);
end;

function TSHA256State.Finalize: TSHA256Digest;
var
  LPad: array[0..127] of Byte;
  LPadLen: SizeUInt;
  LBitLen: UInt64;
  LI: Int32;
begin
  LBitLen := FTotalLen * 8;
  LPadLen := 64 - FBufLen;
  if LPadLen < 9 then Inc(LPadLen, 64);
  FillChar(LPad, SizeOf(LPad), 0);
  LPad[0] := $80;
  PutBE64(@LPad[LPadLen - 8], LBitLen);
  Update(@LPad[0], LPadLen);
  for LI := 0 to 7 do
    PutBE32(@Result[LI * 4], FState[LI]);
end;

{ One-shot SHA256 }

function SHA256(const AData: Pointer; ALen: SizeUInt): TSHA256Digest;
var LS: TSHA256State;
begin
  LS.Init;
  LS.Update(AData, ALen);
  Result := LS.Finalize;
end;

function SHA256Str(const AStr: string): TSHA256Digest;
begin
  if Length(AStr) > 0 then
    Result := SHA256(@AStr[1], Length(AStr))
  else
    Result := SHA256(nil, 0);
end;

function DigestToHex(const ADigest; ALen: Int32): string;
var
  LI: Int32;
  LP: PByte;
const
  HEX: array[0..15] of Char = '0123456789abcdef';
begin
  SetLength(Result, ALen * 2);
  LP := @ADigest;
  for LI := 0 to ALen - 1 do
  begin
    Result[LI * 2 + 1] := HEX[LP[LI] shr 4];
    Result[LI * 2 + 2] := HEX[LP[LI] and $F];
  end;
end;

function SHA256Hex(const AData: Pointer; ALen: SizeUInt): string;
var LD: TSHA256Digest;
begin
  LD := SHA256(AData, ALen);
  Result := DigestToHex(LD, 32);
end;

function SHA256StrHex(const AStr: string): string;
begin
  Result := DigestToHex(SHA256Str(AStr), 32);
end;

{ TMD5State — RFC 1321 }
{$IFDEF ENDIAN_BIG}
{$ERROR MD5 implementation assumes little-endian byte order}
{$ENDIF}

procedure TMD5State.Init;
begin
  FState[0] := $67452301; FState[1] := $efcdab89;
  FState[2] := $98badcfe; FState[3] := $10325476;
  FBufLen := 0;
  FTotalLen := 0;
end;

function ROL32(AVal: UInt32; AShift: Byte): UInt32; inline;
begin
  Result := (AVal shl AShift) or (AVal shr (32 - AShift));
end;

procedure TMD5State.ProcessBlock(const ABlock: Pointer);
var
  M: array[0..15] of UInt32;
  A, B, C, D, F, G: UInt32;
  LI: Int32;
const
  S: array[0..63] of Byte = (
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21);
  K: array[0..63] of UInt32 = (
    $d76aa478,$e8c7b756,$242070db,$c1bdceee,$f57c0faf,$4787c62a,$a8304613,$fd469501,
    $698098d8,$8b44f7af,$ffff5bb1,$895cd7be,$6b901122,$fd987193,$a679438e,$49b40821,
    $f61e2562,$c040b340,$265e5a51,$e9b6c7aa,$d62f105d,$02441453,$d8a1e681,$e7d3fbc8,
    $21e1cde6,$c33707d6,$f4d50d87,$455a14ed,$a9e3e905,$fcefa3f8,$676f02d9,$8d2a4c8a,
    $fffa3942,$8771f681,$6d9d6122,$fde5380c,$a4beea44,$4bdecfa9,$f6bb4b60,$bebfbc70,
    $289b7ec6,$eaa127fa,$d4ef3085,$04881d05,$d9d4d039,$e6db99e5,$1fa27cf8,$c4ac5665,
    $f4292244,$432aff97,$ab9423a7,$fc93a039,$655b59c3,$8f0ccc92,$ffeff47d,$85845dd1,
    $6fa87e4f,$fe2ce6e0,$a3014314,$4e0811a1,$f7537e82,$bd3af235,$2ad7d2bb,$eb86d391);
begin
  Move(ABlock^, M[0], 64);
  A := FState[0]; B := FState[1]; C := FState[2]; D := FState[3];
  for LI := 0 to 63 do
  begin
    if LI < 16 then begin F := (B and C) or ((not B) and D); G := LI; end
    else if LI < 32 then begin F := (D and B) or ((not D) and C); G := (5*LI+1) mod 16; end
    else if LI < 48 then begin F := B xor C xor D; G := (3*LI+5) mod 16; end
    else begin F := C xor (B or (not D)); G := (7*LI) mod 16; end;
    F := F + A + K[LI] + M[G];
    A := D; D := C; C := B; B := B + ROL32(F, S[LI]);
  end;
  FState[0] += A; FState[1] += B; FState[2] += C; FState[3] += D;
end;

procedure TMD5State.Update(const AData: Pointer; ALen: SizeUInt);
var LP: PByte; LCopy: SizeUInt;
begin
  if (ALen = 0) or (AData = nil) then Exit;
  LP := PByte(AData);
  FTotalLen += ALen;
  if FBufLen > 0 then
  begin
    LCopy := 64 - FBufLen;
    if LCopy > ALen then LCopy := ALen;
    Move(LP^, FBuffer[FBufLen], LCopy);
    Inc(FBufLen, LCopy); Inc(LP, LCopy); Dec(ALen, LCopy);
    if FBufLen = 64 then begin ProcessBlock(@FBuffer[0]); FBufLen := 0; end;
  end;
  while ALen >= 64 do begin ProcessBlock(LP); Inc(LP, 64); Dec(ALen, 64); end;
  if ALen > 0 then begin Move(LP^, FBuffer[0], ALen); FBufLen := ALen; end;
end;

procedure TMD5State.UpdateStr(const AStr: string);
begin
  if Length(AStr) > 0 then Update(@AStr[1], Length(AStr));
end;

function TMD5State.Finalize: TMD5Digest;
var LPad: array[0..127] of Byte; LPadLen: SizeUInt; LBitLen: UInt64;
begin
  LBitLen := FTotalLen * 8;
  LPadLen := 64 - FBufLen;
  if LPadLen < 9 then Inc(LPadLen, 64);
  FillChar(LPad, SizeOf(LPad), 0);
  LPad[0] := $80;
  Move(LBitLen, LPad[LPadLen - 8], 8); // little-endian
  Update(@LPad[0], LPadLen);
  Move(FState[0], Result[0], 16);
end;

function MD5(const AData: Pointer; ALen: SizeUInt): TMD5Digest;
var LS: TMD5State;
begin
  LS.Init; LS.Update(AData, ALen); Result := LS.Finalize;
end;

function MD5Str(const AStr: string): TMD5Digest;
begin
  if Length(AStr) > 0 then Result := MD5(@AStr[1], Length(AStr))
  else Result := MD5(nil, 0);
end;

function MD5Hex(const AData: Pointer; ALen: SizeUInt): string;
begin Result := DigestToHex(MD5(AData, ALen), 16); end;

function MD5StrHex(const AStr: string): string;
begin Result := DigestToHex(MD5Str(AStr), 16); end;

{ TCRC32State }

var
  GCRC32Table: array[0..255] of UInt32;
  GCRC32TableInit: Boolean = False;

procedure InitCRC32Table;
var LI, LJ: Int32; LC: UInt32;
begin
  for LI := 0 to 255 do
  begin
    LC := UInt32(LI);
    for LJ := 0 to 7 do
      if (LC and 1) <> 0 then LC := $EDB88320 xor (LC shr 1)
      else LC := LC shr 1;
    GCRC32Table[LI] := LC;
  end;
  GCRC32TableInit := True;
end;

procedure TCRC32State.Init;
begin
  FValue := $FFFFFFFF;
end;

procedure TCRC32State.Update(const AData: Pointer; ALen: SizeUInt);
var LP: PByte; LI: SizeUInt;
begin
  if (AData = nil) or (ALen = 0) then Exit;
  LP := PByte(AData);
  for LI := 1 to ALen do
  begin
    FValue := GCRC32Table[(FValue xor LP^) and $FF] xor (FValue shr 8);
    Inc(LP);
  end;
end;

procedure TCRC32State.UpdateStr(const AStr: string);
begin
  if Length(AStr) > 0 then Update(@AStr[1], Length(AStr));
end;

function TCRC32State.Finalize: UInt32;
begin
  Result := FValue xor $FFFFFFFF;
end;

function CRC32(const AData: Pointer; ALen: SizeUInt): UInt32;
var LS: TCRC32State;
begin
  LS.Init; LS.Update(AData, ALen); Result := LS.Finalize;
end;

function CRC32Str(const AStr: string): UInt32;
begin
  if Length(AStr) > 0 then Result := CRC32(@AStr[1], Length(AStr))
  else Result := CRC32(nil, 0);
end;

{$POP}

initialization
  InitCRC32Table;

end.
