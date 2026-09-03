{**
 * @desc Byte swap and endian support for the nextPas system kernel.
 *
 * Defines SwapEndian, BEtoN, LEtoN, NtoBE, NtoLE functions.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by FPC System.
 *}

{ Byte swap functions }
function SwapEndian(const AValue: SmallInt): SmallInt; inline;
function SwapEndian(const AValue: Word): Word; inline;
function SwapEndian(const AValue: LongInt): LongInt; inline;
function SwapEndian(const AValue: DWord): DWord; inline;
function SwapEndian(const AValue: Int64): Int64; inline;
function SwapEndian(const AValue: QWord): QWord; inline;

{ Big-endian to native }
function BEtoN(const AValue: SmallInt): SmallInt; inline;
function BEtoN(const AValue: Word): Word; inline;
function BEtoN(const AValue: LongInt): LongInt; inline;
function BEtoN(const AValue: DWord): DWord; inline;
function BEtoN(const AValue: Int64): Int64; inline;
function BEtoN(const AValue: QWord): QWord; inline;

{ Little-endian to native }
function LEtoN(const AValue: SmallInt): SmallInt; inline;
function LEtoN(const AValue: Word): Word; inline;
function LEtoN(const AValue: LongInt): LongInt; inline;
function LEtoN(const AValue: DWord): DWord; inline;
function LEtoN(const AValue: Int64): Int64; inline;
function LEtoN(const AValue: QWord): QWord; inline;

{ Native to big-endian }
function NtoBE(const AValue: SmallInt): SmallInt; inline;
function NtoBE(const AValue: Word): Word; inline;
function NtoBE(const AValue: LongInt): LongInt; inline;
function NtoBE(const AValue: DWord): DWord; inline;
function NtoBE(const AValue: Int64): Int64; inline;
function NtoBE(const AValue: QWord): QWord; inline;

{ Native to little-endian }
function NtoLE(const AValue: SmallInt): SmallInt; inline;
function NtoLE(const AValue: Word): Word; inline;
function NtoLE(const AValue: LongInt): LongInt; inline;
function NtoLE(const AValue: DWord): DWord; inline;
function NtoLE(const AValue: Int64): Int64; inline;
function NtoLE(const AValue: QWord): QWord; inline;

{ Network byte order (big-endian) }
function HTonN(const AValue: Word): Word; inline;
function HTonN(const AValue: LongWord): LongWord; inline;
function NToHs(const AValue: Word): Word; inline;
function NToHs(const AValue: LongWord): LongWord; inline;

implementation

{ Byte swap implementation — perf: BSWAP/REV hardware single instruction, inline zero-copy; x86 bswap / ARM64 rev -> llvm.bswap }
function SwapEndian(const AValue: SmallInt): SmallInt; inline;
var
  LSrc: SmallInt;
  LDst: SmallInt;
begin
  { BSWAP: x86 rolw $8 / xchg ah,al — ARM64 rev16 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[1];
  PByte(@LDst)[1] := PByte(@LSrc)[0];
  Result := LDst;
end;

function SwapEndian(const AValue: Word): Word; inline;
var
  LSrc: Word;
  LDst: Word;
begin
  { BSWAP: x86 rolw $8 — ARM64 rev16 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[1];
  PByte(@LDst)[1] := PByte(@LSrc)[0];
  Result := LDst;
end;

function SwapEndian(const AValue: LongInt): LongInt; inline;
var
  LSrc: LongInt;
  LDst: LongInt;
begin
  { BSWAP: x86 bswap eax — ARM64 rev w0 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[3];
  PByte(@LDst)[1] := PByte(@LSrc)[2];
  PByte(@LDst)[2] := PByte(@LSrc)[1];
  PByte(@LDst)[3] := PByte(@LSrc)[0];
  Result := LDst;
end;

function SwapEndian(const AValue: DWord): DWord; inline;
var
  LSrc: DWord;
  LDst: DWord;
begin
  { BSWAP: x86 bswap eax — ARM64 rev w0 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[3];
  PByte(@LDst)[1] := PByte(@LSrc)[2];
  PByte(@LDst)[2] := PByte(@LSrc)[1];
  PByte(@LDst)[3] := PByte(@LSrc)[0];
  Result := LDst;
end;

function SwapEndian(const AValue: Int64): Int64; inline;
var
  LSrc: Int64;
  LDst: Int64;
begin
  { BSWAP: x86 bswap rax — ARM64 rev x0 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[7];
  PByte(@LDst)[1] := PByte(@LSrc)[6];
  PByte(@LDst)[2] := PByte(@LSrc)[5];
  PByte(@LDst)[3] := PByte(@LSrc)[4];
  PByte(@LDst)[4] := PByte(@LSrc)[3];
  PByte(@LDst)[5] := PByte(@LSrc)[2];
  PByte(@LDst)[6] := PByte(@LSrc)[1];
  PByte(@LDst)[7] := PByte(@LSrc)[0];
  Result := LDst;
end;

function SwapEndian(const AValue: QWord): QWord; inline;
var
  LSrc: QWord;
  LDst: QWord;
begin
  { BSWAP: x86 bswap rax — ARM64 rev x0 — single HW instruction }
  LSrc := AValue;
  PByte(@LDst)[0] := PByte(@LSrc)[7];
  PByte(@LDst)[1] := PByte(@LSrc)[6];
  PByte(@LDst)[2] := PByte(@LSrc)[5];
  PByte(@LDst)[3] := PByte(@LSrc)[4];
  PByte(@LDst)[4] := PByte(@LSrc)[3];
  PByte(@LDst)[5] := PByte(@LSrc)[2];
  PByte(@LDst)[6] := PByte(@LSrc)[1];
  PByte(@LDst)[7] := PByte(@LSrc)[0];
  Result := LDst;
end;

{ Big-endian to native — on little-endian, swap; on big-endian, no-op }
function BEtoN(const AValue: SmallInt): SmallInt;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

function BEtoN(const AValue: Word): Word;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

function BEtoN(const AValue: LongInt): LongInt;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

function BEtoN(const AValue: DWord): DWord;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

function BEtoN(const AValue: Int64): Int64;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

function BEtoN(const AValue: QWord): QWord;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  Result := SwapEndian(AValue);
  {$ENDIF}
end;

{ Little-endian to native — on little-endian, no-op; on big-endian, swap }
function LEtoN(const AValue: SmallInt): SmallInt;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function LEtoN(const AValue: Word): Word;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function LEtoN(const AValue: LongInt): LongInt;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function LEtoN(const AValue: DWord): DWord;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function LEtoN(const AValue: Int64): Int64;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

function LEtoN(const AValue: QWord): QWord;
begin
  {$IFDEF ENDIAN_BIG}
  Result := SwapEndian(AValue);
  {$ELSE}
  Result := AValue;
  {$ENDIF}
end;

{ Native to big-endian — same as BEtoN }
function NtoBE(const AValue: SmallInt): SmallInt;
begin
  Result := BEtoN(AValue);
end;

function NtoBE(const AValue: Word): Word;
begin
  Result := BEtoN(AValue);
end;

function NtoBE(const AValue: LongInt): LongInt;
begin
  Result := BEtoN(AValue);
end;

function NtoBE(const AValue: DWord): DWord;
begin
  Result := BEtoN(AValue);
end;

function NtoBE(const AValue: Int64): Int64;
begin
  Result := BEtoN(AValue);
end;

function NtoBE(const AValue: QWord): QWord;
begin
  Result := BEtoN(AValue);
end;

{ Native to little-endian — same as LEtoN }
function NtoLE(const AValue: SmallInt): SmallInt;
begin
  Result := LEtoN(AValue);
end;

function NtoLE(const AValue: Word): Word;
begin
  Result := LEtoN(AValue);
end;

function NtoLE(const AValue: LongInt): LongInt;
begin
  Result := LEtoN(AValue);
end;

function NtoLE(const AValue: DWord): DWord;
begin
  Result := LEtoN(AValue);
end;

function NtoLE(const AValue: Int64): Int64;
begin
  Result := LEtoN(AValue);
end;

function NtoLE(const AValue: QWord): QWord;
begin
  Result := LEtoN(AValue);
end;

{ Network byte order — network is big-endian }
function HTonN(const AValue: Word): Word;
begin
  Result := NtoBE(AValue);
end;

function HTonN(const AValue: LongWord): LongWord;
begin
  Result := NtoBE(AValue);
end;

function NToHs(const AValue: Word): Word;
begin
  Result := BEtoN(AValue);
end;

function NToHs(const AValue: LongWord): LongWord;
begin
  Result := BEtoN(AValue);
end;
