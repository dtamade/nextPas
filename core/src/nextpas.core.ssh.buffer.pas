unit nextpas.core.ssh.buffer;

{** nextpas.core.ssh - RFC 4251 wire 数据类型读写器。
 *
 * TSshWriter 把 byte/boolean/uint32/string/mpint/name-list 打进载荷；
 * TSshReader 做反向解析。所有越界访问抛 ESSHError(sekProtocol)。
 *
 * 约定：string 与 TBytes 之间按原始字节透传（UTF-8 由调用方保证），
 * 不在本单元做字符集转换。PutStringText 入口显式校验 UTF-8，
 * 非法即抛 sekProtocol；STATUS 描述等读侧非法 UTF-8 走替换。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.text.utf8,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors;

type
  { SSH 载荷写入器 }
  TSshWriter = class
  private
    FBuf: TBytes;
    FLen: SizeUInt;
    procedure Ensure(ACount: SizeUInt);
  public
    constructor Create(ACapacityHint: SizeUInt = 256);

    procedure Clear;
    function Count: SizeUInt;
    function ToBytes: TBytes;

    procedure PutByte(AValue: Byte);
    procedure PutBoolean(AValue: Boolean);
    procedure PutUInt32(AValue: UInt32);
    procedure PutUInt64(AValue: UInt64);
    procedure PutStringBytes(const AValue: TBytes);
    procedure PutStringText(const AText: string);
    { 无符号大端 magnitude → RFC 4251 mpint（补符号位前导零；0 编码为空串）}
    procedure PutMPInt(const AMagnitude: TBytes);
    procedure PutNameList(const ANames: array of string);
    procedure PutRaw(const APtr: PByte; ALen: SizeUInt); overload;
    procedure PutRaw(const AValue: TBytes); overload;
  end;

  { SSH 载荷读取器 }
  TSshReader = class
  private
    FData: TBytes;
    FPos: SizeUInt;
    procedure Need(ACount: SizeUInt);
  public
    constructor Create(const AData: TBytes);

    function AtEnd: Boolean;
    function Remaining: SizeUInt;
    function Position: SizeUInt;

    function PeekByte: Byte;
    function ReadByte: Byte;
    procedure Skip(ACount: SizeUInt);
    function ReadBoolean: Boolean;
    function ReadUInt32: UInt32;
    function ReadUInt64: UInt64;
    function ReadStringBytes: TBytes;
    function ReadStringText: string;
    { 解析 mpint 为无符号大端 magnitude（剥离前导零；负数高位按无符号处理）}
    function ReadMPInt: TBytes;
    function ReadNameList: TStringArray;
  end;

function SshTextFromBytes(const ABytes: TBytes): string; inline;
function SshBytesFromText(const AText: string): TBytes; inline;

implementation

uses
  nextpas.core.mem.utils;

{ SshTextFromBytes/SshBytesFromText — raw bytes ↔ string 透传（UTF-8 由调用方保证，不做转换）。
  单源：委托 bytes.ops.BytesToString/StringToBytes 单源（SetLength+单次 Move 零拷贝），
  本单元仅作 ssh CONTRACT 的 inline 薄转发，避免自实现 Move 导致单源漂移。
  perf: inline 薄转发消除调用开销，零拷贝单次 Move，无二次分配；空串/空 bytes 在 bytes.ops 内短路。
  stability: 不手写 Move 取 [0]，无野指针；复用 bytes.ops 异常安全 SetLength。 }
function SshTextFromBytes(const ABytes: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.BytesToString(ABytes);
end;

function SshBytesFromText(const AText: string): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.StringToBytes(AText);
end;

{ TSshWriter }

constructor TSshWriter.Create(ACapacityHint: SizeUInt);
begin
  inherited Create;
  SetLength(FBuf, ACapacityHint);
  FLen := 0;
end;

procedure TSshWriter.Ensure(ACount: SizeUInt);
var
  LNeed: SizeUInt;
  LNewCap: SizeUInt;
begin
  if FLen > High(SizeUInt) - ACount then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: writer overflow');
  LNeed := FLen + ACount;
  if LNeed <= SizeUInt(Length(FBuf)) then
    Exit;
  { perf: 1.5x geometric growth, no forced 256 per small PutByte/PutRaw;
    single SetLength+Move in callers (zero-copy), avoids per-byte 256 waste
    and O(n²) churn; stability: overflow/packet-limit guarded, exception-safe SetLength. }
  LNewCap := SizeUInt(Length(FBuf));
  if LNewCap = 0 then
    LNewCap := 256
  else
    LNewCap := LNewCap + (LNewCap shr 1);
  if LNewCap < LNeed then
    LNewCap := LNeed;
  if LNewCap > SSH_MAX_RECEIVE_PACKET + 1024 then
    LNewCap := SSH_MAX_RECEIVE_PACKET + 1024;
  if LNeed > LNewCap then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: packet too large');
  SetLength(FBuf, LNewCap);
end;

procedure TSshWriter.Clear;
begin
  FLen := 0;
end;

function TSshWriter.Count: SizeUInt;
begin
  Result := FLen;
end;

function TSshWriter.ToBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(FBuf[0], Result[0], FLen);
end;

procedure TSshWriter.PutByte(AValue: Byte);
begin
  Ensure(1);
  FBuf[FLen] := AValue;
  Inc(FLen);
end;

procedure TSshWriter.PutBoolean(AValue: Boolean);
begin
  PutByte(Ord(AValue));
end;

procedure TSshWriter.PutUInt32(AValue: UInt32);
begin
  Ensure(4);
  FBuf[FLen] := Byte(AValue shr 24);
  FBuf[FLen + 1] := Byte((AValue shr 16) and $FF);
  FBuf[FLen + 2] := Byte((AValue shr 8) and $FF);
  FBuf[FLen + 3] := Byte(AValue and $FF);
  Inc(FLen, 4);
end;

procedure TSshWriter.PutStringBytes(const AValue: TBytes);
begin
  PutUInt32(UInt32(Length(AValue)));
  PutRaw(AValue);
end;

procedure TSshWriter.PutStringText(const AText: string);
begin
  if (Length(AText) > 0) and (not UTF8IsValid(PByte(PChar(AText)), SizeUInt(Length(AText)))) then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: PutStringText requires UTF-8');
  PutUInt32(UInt32(Length(AText)));
  if Length(AText) > 0 then
    PutRaw(PByte(PChar(AText)), SizeUInt(Length(AText)));
end;

procedure TSshWriter.PutMPInt(const AMagnitude: TBytes);
var
  LView: TByteSpan;
begin
  LView := StripLeadingZeroView(AMagnitude);
  if IsZeroBytes(AMagnitude) then
  begin
    PutUInt32(0);
    Exit;
  end;
  if (LView.Data^ and $80) <> 0 then
  begin
    PutUInt32(UInt32(LView.Len + 1));
    PutByte(0);
    PutRaw(LView.Data, LView.Len);
  end
  else
  begin
    PutUInt32(UInt32(LView.Len));
    PutRaw(LView.Data, LView.Len);
  end;
end;

procedure TSshWriter.PutNameList(const ANames: array of string);
var
  I: Integer;
  LTotal: SizeUInt;
begin
  if Length(ANames) = 0 then
  begin
    PutStringText('');
    Exit;
  end;
  { perf: zero intermediate TStringArray/StringsJoin heap alloc; single PutUInt32+single Ensure
    + direct Move per element + ',' separator — O(n) single buffer growth, no temp string churn.
    High-freq KEXINIT builds 10 name-lists per handshake; eliminating per-call SetLength(LArr)+
    StringsJoin single alloc cuts 10 heap allocs/handshake → zero heap for PutNameList itself.
    single source: reuses bytes.ops zero-copy Move semantics (no text.strings indirection),
    FBuf direct copy via Move (zero-copy string payload without temp), inline candidate.
    stability: per-element UTF8IsValid mirrors PutStringText, no silent bad encoding; overflow
    guarded via Ensure/packet-limit; resource release unchanged (no alloc to leak). }
  LTotal := 0;
  for I := 0 to High(ANames) do
  begin
    if (Length(ANames[I]) > 0) and (not UTF8IsValid(PByte(PChar(ANames[I])), SizeUInt(Length(ANames[I])))) then
      raise ESSHError.Create(sekProtocol, 'ssh buffer: PutNameList requires UTF-8');
    Inc(LTotal, SizeUInt(Length(ANames[I])));
  end;
  if Length(ANames) > 1 then
    Inc(LTotal, SizeUInt(Length(ANames) - 1));
  PutUInt32(UInt32(LTotal));
  if LTotal = 0 then
    Exit;
  Ensure(LTotal);
  for I := 0 to High(ANames) do
  begin
    if Length(ANames[I]) > 0 then
    begin
      Move(PChar(ANames[I])^, FBuf[FLen], Length(ANames[I]));
      Inc(FLen, SizeUInt(Length(ANames[I])));
    end;
    if I < High(ANames) then
    begin
      FBuf[FLen] := Byte(',');
      Inc(FLen);
    end;
  end;
end;

procedure TSshWriter.PutRaw(const APtr: PByte; ALen: SizeUInt);
begin
  if (ALen = 0) or (APtr = nil) then
    Exit;
  Ensure(ALen);
  Move(APtr^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TSshWriter.PutRaw(const AValue: TBytes);
begin
  if Length(AValue) > 0 then
    PutRaw(@AValue[0], SizeUInt(Length(AValue)));
end;

{ TSshReader }

constructor TSshReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
end;

procedure TSshReader.Need(ACount: SizeUInt);
begin
  if Remaining < ACount then
    raise ESSHError.Create(sekProtocol,
      'ssh buffer: truncated payload (need ' + IntToStr(ACount) +
      ', remaining ' + IntToStr(Remaining) + ')');
end;

function TSshReader.AtEnd: Boolean;
begin
  Result := FPos >= SizeUInt(Length(FData));
end;

function TSshReader.Remaining: SizeUInt;
begin
  Result := SizeUInt(Length(FData)) - FPos;
end;

function TSshReader.Position: SizeUInt;
begin
  Result := FPos;
end;

function TSshReader.PeekByte: Byte;
begin
  Need(1);
  Result := FData[FPos];
end;

function TSshReader.ReadByte: Byte;
begin
  Need(1);
  Result := FData[FPos];
  Inc(FPos);
end;

procedure TSshReader.Skip(ACount: SizeUInt);
begin
  Need(ACount);
  Inc(FPos, ACount);
end;

function TSshReader.ReadBoolean: Boolean;
begin
  Result := ReadByte <> 0;
end;

function TSshReader.ReadUInt32: UInt32;
begin
  Need(4);
  Result := (UInt32(FData[FPos]) shl 24)
    or (UInt32(FData[FPos + 1]) shl 16)
    or (UInt32(FData[FPos + 2]) shl 8)
    or UInt32(FData[FPos + 3]);
  Inc(FPos, 4);
end;

procedure TSshWriter.PutUInt64(AValue: UInt64);
begin
  PutUInt32(UInt32(AValue shr 32));
  PutUInt32(UInt32(AValue and $FFFFFFFF));
end;

function TSshReader.ReadUInt64: UInt64;
begin
  Result := (UInt64(ReadUInt32) shl 32) or UInt64(ReadUInt32);
end;

function TSshReader.ReadStringBytes: TBytes;
var
  LLen: UInt32;
begin
  LLen := ReadUInt32;
  Need(LLen);
  Result := nil;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(FData[FPos], Result[0], LLen);
  Inc(FPos, LLen);
end;

function TSshReader.ReadStringText: string;
begin
  Result := SshTextFromBytes(ReadStringBytes);
end;

function TSshReader.ReadMPInt: TBytes;
var
  LBlob: TBytes;
  LView: TByteSpan;
begin
  LBlob := ReadStringBytes;
  if (Length(LBlob) > 0) and ((LBlob[0] and $80) <> 0) then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: mpint negative');
  LView := StripLeadingZeroView(LBlob);
  Result := nil;
  SetLength(Result, LView.Len);
  if LView.Len > 0 then
    Move(LView.Data^, Result[0], LView.Len);
end;

function TSshReader.ReadNameList: TStringArray;
var
  LJoined: string;
  LParts: TStringArray;
  I, LOut: Integer;
begin
  LJoined := ReadStringText;
  Result := nil;
  SetLength(Result, 0);
  if LJoined = '' then
    Exit;
  LParts := StringsSplit(LJoined, ',');
  LOut := 0;
  SetLength(Result, Length(LParts));
  for I := 0 to High(LParts) do
  begin
    if LParts[I] <> '' then
    begin
      Result[LOut] := LParts[I];
      Inc(LOut);
    end;
  end;
  SetLength(Result, LOut);
end;

end.
