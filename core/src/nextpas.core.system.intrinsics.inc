{**
 * @desc Additional FPC System functions for the nextPas system kernel.
 *
 * Defines bulk fill, search, compare, and utility functions.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by FPC System.
 *}

{ Bulk fill functions }
procedure FillByte(var X; ACount: SizeInt; AValue: Byte); inline;
procedure FillDWord(var X; ACount: SizeInt; AValue: DWord); inline;
procedure FillQWord(var X; ACount: SizeInt; AValue: QWord); inline;

{ Search functions }
function IndexChar(const ABuf; ALen: SizeInt; AByte: AnsiChar): SizeInt;
function IndexByte(const ABuf; ALen: SizeInt; AByte: Byte): SizeInt;
function IndexWord(const ABuf; ALen: SizeInt; AWord: Word): SizeInt;
function IndexDWord(const ABuf; ALen: SizeInt; ADWord: DWord): SizeInt;
function IndexQWord(const ABuf; ALen: SizeInt; AQWord: QWord): SizeInt;

{ Compare functions }
function CompareChar(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
function CompareByte(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
function CompareWord(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
function CompareDWord(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;

{ Null-terminated move }
procedure MoveChar0(const ASrc; var ADest; ALen: SizeInt);

{ Memory search }
function MemPos(ANeedle: PByte; ANeedleLen: SizeUInt; AHaystack: PByte; AHaystackLen: SizeUInt): SizeInt;

{ Stack top }
function StackTop: Pointer;

{ Swap functions }
procedure Swap(var A, B: Byte); overload;
procedure Swap(var A, B: ShortInt); overload;
procedure Swap(var A, B: Word); overload;
procedure Swap(var A, B: SmallInt); overload;
procedure Swap(var A, B: LongWord); overload;
procedure Swap(var A, B: LongInt); overload;
procedure Swap(var A, B: QWord); overload;
procedure Swap(var A, B: Int64); overload;
procedure Swap(var A, B: Pointer); overload;
procedure Swap(var A, B: Boolean); overload;

implementation

{ Bulk fill implementation }
procedure FillByte(var X; ACount: SizeInt; AValue: Byte);
begin
  FillChar(X, ACount, AValue);
end;

procedure FillDWord(var X; ACount: SizeInt; AValue: DWord);
var
  LP: PDWord;
  I: SizeInt;
begin
  LP := PDWord(@X);
  for I := 0 to ACount - 1 do
  begin
    LP^ := AValue;
    Inc(LP);
  end;
end;

procedure FillQWord(var X; ACount: SizeInt; AValue: QWord);
var
  LP: PQWord;
  I: SizeInt;
begin
  LP := PQWord(@X);
  for I := 0 to ACount - 1 do
  begin
    LP^ := AValue;
    Inc(LP);
  end;
end;

{ Search implementation }
function IndexChar(const ABuf; ALen: SizeInt; AByte: AnsiChar): SizeInt;
var
  LP: PAnsiChar;
  I: SizeInt;
begin
  LP := PAnsiChar(@ABuf);
  for I := 0 to ALen - 1 do
  begin
    if LP^ = AByte then
      Exit(I);
    Inc(LP);
  end;
  Result := -1;
end;

function IndexByte(const ABuf; ALen: SizeInt; AByte: Byte): SizeInt;
var
  LP: PByte;
  I: SizeInt;
begin
  LP := PByte(@ABuf);
  for I := 0 to ALen - 1 do
  begin
    if LP^ = AByte then
      Exit(I);
    Inc(LP);
  end;
  Result := -1;
end;

function IndexWord(const ABuf; ALen: SizeInt; AWord: Word): SizeInt;
var
  LP: PWord;
  I: SizeInt;
begin
  LP := PWord(@ABuf);
  for I := 0 to ALen - 1 do
  begin
    if LP^ = AWord then
      Exit(I);
    Inc(LP);
  end;
  Result := -1;
end;

function IndexDWord(const ABuf; ALen: SizeInt; ADWord: DWord): SizeInt;
var
  LP: PDWord;
  I: SizeInt;
begin
  LP := PDWord(@ABuf);
  for I := 0 to ALen - 1 do
  begin
    if LP^ = ADWord then
      Exit(I);
    Inc(LP);
  end;
  Result := -1;
end;

function IndexQWord(const ABuf; ALen: SizeInt; AQWord: QWord): SizeInt;
var
  LP: PQWord;
  I: SizeInt;
begin
  LP := PQWord(@ABuf);
  for I := 0 to ALen - 1 do
  begin
    if LP^ = AQWord then
      Exit(I);
    Inc(LP);
  end;
  Result := -1;
end;

{ Compare implementation }
function CompareChar(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
var
  LP1, LP2: PAnsiChar;
  I: SizeInt;
begin
  LP1 := PAnsiChar(@ABuf1);
  LP2 := PAnsiChar(@ABuf2);
  for I := 0 to ALen - 1 do
  begin
    if LP1^ <> LP2^ then
      Exit(Ord(LP1^) - Ord(LP2^));
    Inc(LP1);
    Inc(LP2);
  end;
  Result := 0;
end;

function CompareByte(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
var
  LP1, LP2: PByte;
  I: SizeInt;
begin
  LP1 := PByte(@ABuf1);
  LP2 := PByte(@ABuf2);
  for I := 0 to ALen - 1 do
  begin
    if LP1^ <> LP2^ then
      Exit(Ord(LP1^) - Ord(LP2^));
    Inc(LP1);
    Inc(LP2);
  end;
  Result := 0;
end;

function CompareWord(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
var
  LP1, LP2: PWord;
  I: SizeInt;
begin
  LP1 := PWord(@ABuf1);
  LP2 := PWord(@ABuf2);
  for I := 0 to ALen - 1 do
  begin
    if LP1^ <> LP2^ then
      Exit(Ord(LP1^) - Ord(LP2^));
    Inc(LP1);
    Inc(LP2);
  end;
  Result := 0;
end;

function CompareDWord(const ABuf1, ABuf2; ALen: SizeInt): SizeInt;
var
  LP1, LP2: PDWord;
  I: SizeInt;
begin
  LP1 := PDWord(@ABuf1);
  LP2 := PDWord(@ABuf2);
  for I := 0 to ALen - 1 do
  begin
    if LP1^ <> LP2^ then
      Exit(Ord(LP1^) - Ord(LP2^));
    Inc(LP1);
    Inc(LP2);
  end;
  Result := 0;
end;

{ Null-terminated move implementation }
procedure MoveChar0(const ASrc; var ADest; ALen: SizeInt);
var
  LP1, LP2: PAnsiChar;
  I: SizeInt;
begin
  LP1 := PAnsiChar(@ASrc);
  LP2 := PAnsiChar(@ADest);
  for I := 0 to ALen - 1 do
  begin
    LP2^ := LP1^;
    if LP1^ = #0 then
      Exit;
    Inc(LP1);
    Inc(LP2);
  end;
  LP2^ := #0;
end;

{ Memory search implementation }
function MemPos(ANeedle: PByte; ANeedleLen: SizeUInt; AHaystack: PByte; AHaystackLen: SizeUInt): SizeInt;
var
  I, J: SizeUInt;
  Match: Boolean;
begin
  if (ANeedleLen = 0) or (AHaystackLen < ANeedleLen) then
    Exit(-1);
  for I := 0 to AHaystackLen - ANeedleLen do
  begin
    Match := True;
    for J := 0 to ANeedleLen - 1 do
    begin
      if AHaystack[I + J] <> ANeedle[J] then
      begin
        Match := False;
        Break;
      end;
    end;
    if Match then
      Exit(I);
  end;
  Result := -1;
end;

{ Stack top implementation — returns address of stack top }
function StackTop: Pointer;
var
  LStackVar: Byte;
begin
  Result := @LStackVar;
end;

{ Swap implementation }
procedure Swap(var A, B: Byte);
var T: Byte; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: ShortInt);
var T: ShortInt; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: Word);
var T: Word; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: SmallInt);
var T: SmallInt; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: LongWord);
var T: LongWord; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: LongInt);
var T: LongInt; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: QWord);
var T: QWord; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: Int64);
var T: Int64; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: Pointer);
var T: Pointer; begin T := A; A := B; B := T; end;

procedure Swap(var A, B: Boolean);
var T: Boolean; begin T := A; A := B; B := T; end;
