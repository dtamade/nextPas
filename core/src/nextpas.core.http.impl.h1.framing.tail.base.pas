unit nextpas.core.http.impl.h1.framing.tail.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops;

type
  TH1TailBuffer = record
    Data: TBytes;
    Len: SizeInt;
    procedure Init; inline;
    procedure Clear; inline;
    function AsSpan: TByteSpan; inline;
    function IsEmpty: Boolean; inline;
  end;

implementation

procedure TH1TailBuffer.Init; inline;
begin
  Data := nil;
  Len := 0;
end;

procedure TH1TailBuffer.Clear; inline;
begin
  { stability: release without leak; Data managed, no heap leak on Clear/Destroy }
  Data := nil;
  Len := 0;
end;

function TH1TailBuffer.AsSpan: TByteSpan; inline;
begin
  { perf: zero-copy view over FPending, no allocation, single TByteSpan slice }
  if (Data <> nil) and (Len > 0) then
    Result := TByteSpan.Create(@Data[0], Len)
  else
    Result := TByteSpan.Create(nil, 0);
end;

function TH1TailBuffer.IsEmpty: Boolean; inline;
begin
  Result := Len = 0;
end;

end.
