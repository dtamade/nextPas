unit nextpas.core.sse;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sse.base,
  nextpas.core.sse.parser;

type
  TSseEvent = nextpas.core.sse.base.TSseEvent;
  TSseEventArray = nextpas.core.sse.base.TSseEventArray;
  TSseParser = nextpas.core.sse.parser.TSseParser;

function SseParseAll(const AInput: string): TSseEventArray;
function TrySseParseAll(const AInput: string; out AEvents: TSseEventArray): Boolean;

implementation

function SseParseAll(const AInput: string): TSseEventArray;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
  LCount: SizeUInt;
begin
  SetLength(Result, 0);
  LCount := 0;
  LParser := TSseParser.Create;
  try
    LParser.Feed(AInput);
    LParser.Finish;
    while LParser.TryReadEvent(LEvent) do
    begin
      Inc(LCount);
      SetLength(Result, LCount);
      Result[LCount - 1] := LEvent;
    end;
  finally
    LParser.Free;
  end;
end;

function TrySseParseAll(const AInput: string; out AEvents: TSseEventArray): Boolean;
begin
  AEvents := SseParseAll(AInput);
  Result := Length(AEvents) > 0;
end;

end.
