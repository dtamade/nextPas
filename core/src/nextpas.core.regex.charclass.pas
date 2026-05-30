unit nextpas.core.regex.charclass;

{$I nextpas.core.settings.inc}

interface

type
  TCharBitmap = array[0..31] of Byte;

procedure CharBitmapClear(var ABitmap: TCharBitmap);
procedure CharBitmapSet(var ABitmap: TCharBitmap; ACh: Byte); inline;
procedure CharBitmapSetRange(var ABitmap: TCharBitmap; ALo, AHi: Byte);
function CharBitmapTest(const ABitmap: TCharBitmap; ACh: Byte): Boolean; inline;
procedure CharBitmapNegate(var ABitmap: TCharBitmap);

procedure CharBitmapInitDigit(var ABitmap: TCharBitmap);
procedure CharBitmapInitWord(var ABitmap: TCharBitmap);
procedure CharBitmapInitSpace(var ABitmap: TCharBitmap);

function IsWordChar(ACh: Byte): Boolean; inline;

implementation

procedure CharBitmapClear(var ABitmap: TCharBitmap);
begin
  FillChar(ABitmap, SizeOf(ABitmap), 0);
end;

procedure CharBitmapSet(var ABitmap: TCharBitmap; ACh: Byte);
begin
  ABitmap[ACh shr 3] := ABitmap[ACh shr 3] or (1 shl (ACh and 7));
end;

procedure CharBitmapSetRange(var ABitmap: TCharBitmap; ALo, AHi: Byte);
var i: Integer;
begin
  for i := ALo to AHi do
    CharBitmapSet(ABitmap, Byte(i));
end;

function CharBitmapTest(const ABitmap: TCharBitmap; ACh: Byte): Boolean;
begin
  Result := (ABitmap[ACh shr 3] and (1 shl (ACh and 7))) <> 0;
end;

procedure CharBitmapNegate(var ABitmap: TCharBitmap);
var i: Integer;
begin
  for i := 0 to 31 do
    ABitmap[i] := not ABitmap[i];
end;

procedure CharBitmapInitDigit(var ABitmap: TCharBitmap);
begin
  CharBitmapClear(ABitmap);
  CharBitmapSetRange(ABitmap, Ord('0'), Ord('9'));
end;

procedure CharBitmapInitWord(var ABitmap: TCharBitmap);
begin
  CharBitmapClear(ABitmap);
  CharBitmapSetRange(ABitmap, Ord('a'), Ord('z'));
  CharBitmapSetRange(ABitmap, Ord('A'), Ord('Z'));
  CharBitmapSetRange(ABitmap, Ord('0'), Ord('9'));
  CharBitmapSet(ABitmap, Ord('_'));
end;

procedure CharBitmapInitSpace(var ABitmap: TCharBitmap);
begin
  CharBitmapClear(ABitmap);
  CharBitmapSet(ABitmap, Ord(' '));
  CharBitmapSet(ABitmap, 9);   // \t
  CharBitmapSet(ABitmap, 10);  // \n
  CharBitmapSet(ABitmap, 13);  // \r
  CharBitmapSet(ABitmap, 12);  // \f
  CharBitmapSet(ABitmap, 11);  // \v
end;

function IsWordChar(ACh: Byte): Boolean;
begin
  case Chr(ACh) of
    'a'..'z', 'A'..'Z', '0'..'9', '_': Result := True;
  else
    Result := False;
  end;
end;

end.
