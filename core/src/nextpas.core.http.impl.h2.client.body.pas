unit nextpas.core.http.impl.h2.client.body;
{**
 * @desc H2 client response body IReader over an owned TBytes snapshot.
 *       Mechanical extract from impl.h2.client (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf;

type
  TH2ClientResponseBodyReader = class(TInterfacedObject, IReader)
  private
    FData: nextpas.core.base.TBytes;
    FPosition: SizeInt;
  public
    constructor Create(const AData: nextpas.core.base.TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

implementation

constructor TH2ClientResponseBodyReader.Create(
  const AData: nextpas.core.base.TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
end;

function TH2ClientResponseBodyReader.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  Result := 0;
  if (ACount = 0) or (FPosition >= Length(FData)) then
    Exit;
  LAvailable := SizeUInt(Length(FData) - FPosition);
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  if Result = 0 then
    Exit;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, SizeInt(Result));
end;

end.