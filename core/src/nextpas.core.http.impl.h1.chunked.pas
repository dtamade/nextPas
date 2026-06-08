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
  nextpas.core.text.number;

procedure WriteAllOrRaise(const AWriter: IWriter; const ABuf;
  const ACount: SizeUInt);
var
  LWritten: SizeUInt;
  LTotal: SizeUInt;
  LPtr: PByte;
begin
  if ACount = 0 then
    Exit;
  LPtr := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LWritten := AWriter.Write(LPtr[LTotal], ACount - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('chunked writer: write failed (zero progress)');
    if LWritten > ACount - LTotal then
      raise EIOError.Create('chunked writer: write over-reported progress');
    Inc(LTotal, LWritten);
  end;
end;

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
  WriteAllOrRaise(FInner, LHex[0], SizeUInt(LHexLen));
  WriteAllOrRaise(FInner, PAnsiChar(#13#10)^, 2);
  WriteAllOrRaise(FInner, ABuf, ACount);
  WriteAllOrRaise(FInner, PAnsiChar(#13#10)^, 2);
  Result := ACount;
end;

procedure TChunkedWriter.Flush;
begin
  if not FFinished then
  begin
    WriteAllOrRaise(FInner, PAnsiChar('0'#13#10#13#10)^, 5);
    FFinished := True;
  end;
end;

end.
