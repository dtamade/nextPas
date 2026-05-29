unit nextpas.core.hash.wyhash;

{$I nextpas.core.settings.inc}

interface

function WyHash(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64 = 0): UInt64;
function WyHashStr(const S: AnsiString; ASeed: UInt64 = 0): UInt64;
function WyHash32(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64 = 0): UInt32; inline;
function WyHashStr32(const S: AnsiString; ASeed: UInt64 = 0): UInt32; inline;

implementation

const
  WY_P0 = UInt64($a0761d6478bd642f);
  WY_P1 = UInt64($e7037ed1a0b428db);
  WY_P2 = UInt64($8ebc6af09c88c6e3);
  WY_P3 = UInt64($589965cc75374cc3);

function WyMix(A, B: UInt64): UInt64; inline;
var lo, hi: UInt64;
begin
  {$PUSH}{$Q-}{$R-}
  lo := A * B;
  hi := ((A shr 32) * (B and $FFFFFFFF) + (A and $FFFFFFFF) * (B shr 32)
        + (A shr 32) * (B shr 32) shl 32);
  // Proper 128-bit multiply: use compiler intrinsic if available
  // Simplified: use the xor-fold approach
  Result := lo xor hi;
  {$POP}
end;

function WyR8(p: PByte): UInt64; inline;
begin
  Result := PUInt64(p)^;
end;

function WyR4(p: PByte): UInt64; inline;
begin
  Result := PUInt32(p)^;
end;

function WyR3(p: PByte; k: SizeUInt): UInt64; inline;
begin
  Result := (UInt64(p[0]) shl 16) or (UInt64(p[k shr 1]) shl 8) or UInt64(p[k - 1]);
end;

function WyHash(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64): UInt64;
var
  p: PByte;
  a, b, seed: UInt64;
  i: SizeUInt;
begin
  {$PUSH}{$Q-}{$R-}
  p := PByte(AData);
  seed := ASeed xor WY_P0;

  if ALen <= 16 then
  begin
    if ALen >= 4 then
    begin
      a := (WyR4(p) shl 32) or WyR4(p + ((ALen shr 3) shl 2));
      b := (WyR4(p + ALen - 4) shl 32) or WyR4(p + ALen - 4 - ((ALen shr 3) shl 2));
    end
    else if ALen > 0 then
    begin
      a := WyR3(p, ALen);
      b := 0;
    end
    else
    begin
      a := 0;
      b := 0;
    end;
  end
  else if ALen <= 48 then
  begin
    i := 0;
    while i + 16 <= ALen do
    begin
      seed := WyMix(WyR8(p + i) xor WY_P1, WyR8(p + i + 8) xor seed);
      Inc(i, 16);
    end;
    a := WyR8(p + ALen - 16);
    b := WyR8(p + ALen - 8);
  end
  else
  begin
    i := 0;
    while i + 48 <= ALen do
    begin
      seed := WyMix(WyR8(p + i) xor WY_P1, WyR8(p + i + 8) xor seed);
      seed := WyMix(WyR8(p + i + 16) xor WY_P2, WyR8(p + i + 24) xor seed);
      seed := WyMix(WyR8(p + i + 32) xor WY_P3, WyR8(p + i + 40) xor seed);
      Inc(i, 48);
    end;
    while i + 16 <= ALen do
    begin
      seed := WyMix(WyR8(p + i) xor WY_P1, WyR8(p + i + 8) xor seed);
      Inc(i, 16);
    end;
    a := WyR8(p + ALen - 16);
    b := WyR8(p + ALen - 8);
  end;

  Result := WyMix(WY_P1 xor ALen, WyMix(a xor WY_P1, b xor seed));
  {$POP}
end;

function WyHashStr(const S: AnsiString; ASeed: UInt64): UInt64;
begin
  if Length(S) = 0 then
    Result := WyMix(ASeed xor WY_P0, WY_P1)
  else
    Result := WyHash(@S[1], SizeUInt(Length(S)), ASeed);
end;

function WyHash32(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64): UInt32;
var h: UInt64;
begin
  h := WyHash(AData, ALen, ASeed);
  Result := UInt32(h xor (h shr 32));
end;

function WyHashStr32(const S: AnsiString; ASeed: UInt64): UInt32;
var h: UInt64;
begin
  h := WyHashStr(S, ASeed);
  Result := UInt32(h xor (h shr 32));
end;

end.
