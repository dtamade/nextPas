unit nextpas.core.io.collect;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.io.intf,
  nextpas.core.io.scanner;

function CollectLines(const AScanner: IScanner): TStringArray;
function CollectLinesFrom(const AReader: IReader): TStringArray;
function CountLines(const AScanner: IScanner): Int32;

implementation

function CollectLines(const AScanner: IScanner): TStringArray;
var
  LCount, LCap: Int32;
begin
  Result := nil;
  LCount := 0;
  LCap := 64;
  SetLength(Result, LCap);
  while AScanner.Scan do
  begin
    if LCount >= LCap then
    begin
      LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
    Result[LCount] := AScanner.Text;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function CollectLinesFrom(const AReader: IReader): TStringArray;
var
  LScanner: IScanner;
begin
  LScanner := CreateScanner(AReader);
  Result := CollectLines(LScanner);
end;

function CountLines(const AScanner: IScanner): Int32;
begin
  Result := 0;
  while AScanner.Scan do
    Inc(Result);
end;

end.
