unit nextpas.core.http.impl.h1.chunked;
{**
 * @desc Chunked Transfer-Encoding writer for HTTP/1.1 responses.
 *       Wraps an inner IWriter, framing each Write as a chunk.
 *       Flush sends the terminal 0-length chunk.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.io.intf;

type
  TChunkedWriter = class(TInterfacedObject, IWriter, IFlusher)
  private
    FInner: IWriter;
    FFinished: Boolean;
  public
    constructor Create(const AInner: IWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.number,
  nextpas.core.io.util;

constructor TChunkedWriter.Create(const AInner: IWriter);
begin
  inherited Create;
  FInner := AInner;
  FFinished := False;
end;

function TChunkedWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LHex: array[0..15] of AnsiChar;
  LHexLen: Int32;
begin
  if ACount = 0 then Exit(0);
  if FFinished then
    raise EHttpError.Create('chunked response already finalized');
  LHexLen := IntToHexBuffer(UInt64(ACount), @LHex[0], 1);
  IoWriteAll(FInner, LHex[0], SizeUInt(LHexLen));
  IoWriteAll(FInner, PAnsiChar(#13#10)^, 2);
  IoWriteAll(FInner, ABuf, ACount);
  IoWriteAll(FInner, PAnsiChar(#13#10)^, 2);
  Result := ACount;
end;

procedure TChunkedWriter.Flush;
begin
  if not FFinished then
  begin
    IoWriteAll(FInner, PAnsiChar('0'#13#10#13#10)^, 5);
    FFinished := True;
  end;
end;

end.
