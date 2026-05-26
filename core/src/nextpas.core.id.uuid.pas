unit nextpas.core.id.uuid;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base;

function UuidV4: TUuidString;

implementation

const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';

function UuidV4: TUuidString;
var
  LBytes: array[0..15] of Byte;
  LI: Integer;
  LJ: Integer;
begin
  for LI := 0 to 15 do
    LBytes[LI] := Byte(Random(256));

  LBytes[6] := (LBytes[6] and $0F) or $40;
  LBytes[8] := (LBytes[8] and $3F) or $80;

  SetLength(Result, UUID_LENGTH);
  LJ := 1;
  for LI := 0 to 15 do
  begin
    Result[LJ]     := HEX_CHARS[LBytes[LI] shr 4];
    Result[LJ + 1] := HEX_CHARS[LBytes[LI] and $0F];
    Inc(LJ, 2);
    if (LI = 3) or (LI = 5) or (LI = 7) or (LI = 9) then
    begin
      Result[LJ] := '-';
      Inc(LJ);
    end;
  end;
end;

end.
