unit nextpas.core.http.impl.h1.framing.tail.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h1.framing.tail.base,
  nextpas.core.bytes.ops;

type
  IHttpTailFraming = interface
    ['{D2E3F4A5-B6C7-4D8E-9F0A-4567890123DE}']
    function HasPending: Boolean;
    function PendingSpan: TByteSpan;
    procedure Isolate(const AExtra: TByteSpan);
    procedure Clear;
  end;

function TailIsolationPreservesRequest(const APending: TByteSpan; const ACurrentLen: SizeInt): Boolean; inline;

implementation

function TailIsolationPreservesRequest(const APending: TByteSpan; const ACurrentLen: SizeInt): Boolean; inline;
begin
  { perf: inline isolation check, zero-copy pending view never pollutes current request headers/body }
  Result := (APending.Data = nil) or (ACurrentLen = 0) or (APending.Len = 0);
end;

end.
