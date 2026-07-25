unit nextpas.core.http.impl.h2.wire;
{**
 * @desc Shared H2 read/write buffer record + pure free helpers.
 *       Mechanical extract from impl.h2.client / impl.h2.session
 *       (behavior freeze). I/O and protocol demux stay on owners.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.frame;

const
  { Session-side hard cap on stored read bytes (after compact). }
  H2_WIRE_READ_HARD_LIMIT: SizeInt = 16 * 1024 * 1024;
  { Compact wasted read prefix when it dominates (client demux path). }
  H2_WIRE_COMPACT_PREFIX_MIN: SizeInt = 8192;

type
  { Connection-level wire buffers. ReadPos is 0-based into ReadBuf
    (1-based AnsiString indexing). }
  TH2WireBuffers = record
    ReadBuf: AnsiString;
    ReadPos: SizeInt;
    WriteBuf: AnsiString;
  end;

procedure H2WireInit(out AWire: TH2WireBuffers);
procedure H2WireClear(var AWire: TH2WireBuffers);
procedure H2WireClearRead(var AWire: TH2WireBuffers);
procedure H2WireClearWrite(var AWire: TH2WireBuffers);

function H2WireReadAvailable(const AWire: TH2WireBuffers): SizeInt; inline;
function H2WireReadStored(const AWire: TH2WireBuffers): SizeInt; inline;
function H2WireHasReadData(const AWire: TH2WireBuffers): Boolean; inline;
function H2WireHasWriteData(const AWire: TH2WireBuffers): Boolean; inline;

function H2WireReadPtr(const AWire: TH2WireBuffers): PAnsiChar; inline;
function H2WireWritePtr(const AWire: TH2WireBuffers): PAnsiChar; inline;

procedure H2WireAppendWrite(var AWire: TH2WireBuffers; const ABytes: AnsiString);
procedure H2WireAppendReadBytes(var AWire: TH2WireBuffers; const ASrc;
  const ALen: SizeInt);
procedure H2WirePrepareAppendRead(var AWire: TH2WireBuffers);
procedure H2WireCompactRead(var AWire: TH2WireBuffers);
procedure H2WireDiscardConsumed(var AWire: TH2WireBuffers;
  const AConsumed: SizeUInt);
{ Drop AWritten bytes from the front of WriteBuf (partial drain). }
procedure H2WireConsumeWriteFront(var AWire: TH2WireBuffers;
  const AWritten: SizeUInt);

function H2WireTryDecodeFrame(const AWire: TH2WireBuffers;
  out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
function H2WirePeekFrameHeader(const AWire: TH2WireBuffers;
  out AHeader: TH2FrameHeader): Boolean;
function H2WireHasFullFrame(const AWire: TH2WireBuffers;
  const AHeader: TH2FrameHeader): Boolean;

implementation

procedure H2WireInit(out AWire: TH2WireBuffers);
begin
  AWire.ReadBuf := '';
  AWire.ReadPos := 0;
  AWire.WriteBuf := '';
end;

procedure H2WireClear(var AWire: TH2WireBuffers);
begin
  H2WireInit(AWire);
end;

procedure H2WireClearRead(var AWire: TH2WireBuffers);
begin
  AWire.ReadBuf := '';
  AWire.ReadPos := 0;
end;

procedure H2WireClearWrite(var AWire: TH2WireBuffers);
begin
  AWire.WriteBuf := '';
end;

function H2WireReadAvailable(const AWire: TH2WireBuffers): SizeInt; inline;
begin
  Result := Length(AWire.ReadBuf) - AWire.ReadPos;
  if Result < 0 then
    Result := 0;
end;

function H2WireReadStored(const AWire: TH2WireBuffers): SizeInt; inline;
begin
  Result := Length(AWire.ReadBuf);
end;

function H2WireHasReadData(const AWire: TH2WireBuffers): Boolean; inline;
begin
  Result := H2WireReadAvailable(AWire) > 0;
end;

function H2WireHasWriteData(const AWire: TH2WireBuffers): Boolean; inline;
begin
  Result := AWire.WriteBuf <> '';
end;

function H2WireReadPtr(const AWire: TH2WireBuffers): PAnsiChar; inline;
begin
  if H2WireReadAvailable(AWire) <= 0 then
    Exit(nil);
  Result := @AWire.ReadBuf[AWire.ReadPos + 1];
end;

function H2WireWritePtr(const AWire: TH2WireBuffers): PAnsiChar; inline;
begin
  if AWire.WriteBuf = '' then
    Exit(nil);
  Result := @AWire.WriteBuf[1];
end;

procedure H2WireAppendWrite(var AWire: TH2WireBuffers; const ABytes: AnsiString);
var
  LOldLen: SizeInt;
  LAdd: SizeInt;
begin
  if ABytes = '' then
    Exit;
  LAdd := Length(ABytes);
  LOldLen := Length(AWire.WriteBuf);
  SetLength(AWire.WriteBuf, LOldLen + LAdd);
  Move(ABytes[1], AWire.WriteBuf[LOldLen + 1], LAdd);
end;

procedure H2WirePrepareAppendRead(var AWire: TH2WireBuffers);
begin
  { Drop consumed prefix before appending so the string does not grow forever. }
  if AWire.ReadPos > 0 then
    H2WireCompactRead(AWire);
end;

procedure H2WireAppendReadBytes(var AWire: TH2WireBuffers; const ASrc;
  const ALen: SizeInt);
var
  LOldLen: SizeInt;
begin
  if ALen <= 0 then
    Exit;
  LOldLen := Length(AWire.ReadBuf);
  SetLength(AWire.ReadBuf, LOldLen + ALen);
  Move(ASrc, AWire.ReadBuf[LOldLen + 1], ALen);
end;

procedure H2WireCompactRead(var AWire: TH2WireBuffers);
var
  LRemain: SizeInt;
  LNew: AnsiString;
begin
  if AWire.ReadPos <= 0 then
    Exit;
  LRemain := Length(AWire.ReadBuf) - AWire.ReadPos;
  if LRemain <= 0 then
  begin
    AWire.ReadBuf := '';
    AWire.ReadPos := 0;
    Exit;
  end;
  SetLength(LNew, LRemain);
  Move(AWire.ReadBuf[AWire.ReadPos + 1], LNew[1], LRemain);
  AWire.ReadBuf := LNew;
  AWire.ReadPos := 0;
end;

procedure H2WireDiscardConsumed(var AWire: TH2WireBuffers;
  const AConsumed: SizeUInt);
var
  LAvail: SizeInt;
begin
  if AConsumed = 0 then
    Exit;
  LAvail := H2WireReadAvailable(AWire);
  if AConsumed >= SizeUInt(LAvail) then
  begin
    AWire.ReadBuf := '';
    AWire.ReadPos := 0;
    Exit;
  end;
  Inc(AWire.ReadPos, SizeInt(AConsumed));
  { Compact when wasted prefix dominates (keep demux loop O(frame) not O(buffer)). }
  if (AWire.ReadPos >= H2_WIRE_COMPACT_PREFIX_MIN) and
     (AWire.ReadPos * 2 >= Length(AWire.ReadBuf)) then
    H2WireCompactRead(AWire);
end;

procedure H2WireConsumeWriteFront(var AWire: TH2WireBuffers;
  const AWritten: SizeUInt);
var
  LRemaining: SizeInt;
begin
  if AWritten = 0 then
    Exit;
  if AWritten >= SizeUInt(Length(AWire.WriteBuf)) then
  begin
    AWire.WriteBuf := '';
    Exit;
  end;
  LRemaining := Length(AWire.WriteBuf) - SizeInt(AWritten);
  Move(AWire.WriteBuf[AWritten + 1], AWire.WriteBuf[1], LRemaining);
  SetLength(AWire.WriteBuf, LRemaining);
end;

function H2WireTryDecodeFrame(const AWire: TH2WireBuffers;
  out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
var
  LAvail: SizeInt;
  LPtr: PAnsiChar;
begin
  LAvail := H2WireReadAvailable(AWire);
  if LAvail <= 0 then
  begin
    AFrame := Default(TH2Frame);
    AConsumed := 0;
    Exit(False);
  end;
  LPtr := H2WireReadPtr(AWire);
  Result := H2DecodeFrame(LPtr, LAvail, AFrame, AConsumed);
end;

function H2WirePeekFrameHeader(const AWire: TH2WireBuffers;
  out AHeader: TH2FrameHeader): Boolean;
var
  LAvail: SizeInt;
begin
  Result := False;
  AHeader := Default(TH2FrameHeader);
  LAvail := H2WireReadAvailable(AWire);
  if LAvail < H2_FRAME_HEADER_SIZE then
    Exit;
  Result := H2DecodeFrameHeader(H2WireReadPtr(AWire), H2_FRAME_HEADER_SIZE,
    AHeader);
end;

function H2WireHasFullFrame(const AWire: TH2WireBuffers;
  const AHeader: TH2FrameHeader): Boolean;
begin
  Result := SizeUInt(H2_FRAME_HEADER_SIZE) + SizeUInt(AHeader.Len) <=
    SizeUInt(H2WireReadAvailable(AWire));
end;

end.