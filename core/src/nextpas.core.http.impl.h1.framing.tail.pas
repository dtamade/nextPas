unit nextpas.core.http.impl.h1.framing.tail;
{**
 * @desc Keep-Alive Request-Tail (INV-12) framing facade (L3 http.impl.h1 domain extracted per CONTRACT §1.1 §3.1).
 *       Owns FPending isolation semantics (request isolation + deferred follow-up parse). Four-piece base←intf←facade.
 *       L0-L3 ok (depends bytes.ops single source, impl.h1.parser). perf: inline + zero-copy TByteSpan view, no tail copy.
 *       stability: Clear releases pending on connection Close without leak.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h1.framing.tail.base,
  nextpas.core.http.impl.h1.framing.tail.intf,
  nextpas.core.bytes.ops;

type
  TH1TailBuffer = nextpas.core.http.impl.h1.framing.tail.base.TH1TailBuffer;
  IHttpTailFraming = nextpas.core.http.impl.h1.framing.tail.intf.IHttpTailFraming;

function TailSpanFromPending(const AData: TBytes; ALen: SizeInt): TByteSpan; inline;
procedure TailClearPending(var ATail: TH1TailBuffer); inline;

implementation

function TailSpanFromPending(const AData: TBytes; ALen: SizeInt): TByteSpan; inline;
begin
  { perf: inline zero-copy view, bytes.ops single source TByteSpan, no Move; pending never copied into current request }
  if (AData <> nil) and (ALen > 0) then
    Result := TByteSpan.Create(@AData[0], ALen)
  else
    Result := TByteSpan.Create(nil, 0);
end;

procedure TailClearPending(var ATail: TH1TailBuffer); inline;
begin
  ATail.Clear;
end;

end.
