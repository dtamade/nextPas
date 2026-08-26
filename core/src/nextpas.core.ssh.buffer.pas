unit nextpas.core.ssh.buffer;

{** nextpas.core.ssh - RFC 4251 wire 数据类型读写器。
 *
 * TsshWriter 把 byte/boolean/uint32/string/mpint/name-list 打进载荷；
 * TsshReader 做反向解析。所有越界访问抛 ESSHError(sekProtocol)。
 *
 * 约定：string 与 TBytes 之间按原始字节透传（UTF-8 由调用方保证），
 * 不在本单元做字符集转换。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.ssh.errors;

type
  { SSH 载荷写入器 }
  TsshWriter = class
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
  TsshReader = class
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

function SshTextFromBytes(const ABytes: TBytes): string;
function SshBytesFromText(const AText: string): TBytes;

implementation

function SshTextFromBytes(const ABytes: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], PByte(PChar(Result))^, Length(ABytes));
end;

function SshBytesFromText(const AText: string): TBytes;
var
  LLen: SizeUInt;
begin
  Result := nil;
  LLen := SizeUInt(Length(AText));
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(PByte(PChar(AText))^, Result[0], LLen);
end;

{ TsshWriter }

constructor TsshWriter.Create(ACapacityHint: SizeUInt);
begin
  inherited Create;
  SetLength(FBuf, ACapacityHint);
  FLen := 0;
end;

procedure TsshWriter.Ensure(ACount: SizeUInt);
begin
  if FLen + ACount > SizeUInt(Length(FBuf)) then
  begin
    if ACount < 256 then
      ACount := 256;
    SetLength(FBuf, SizeUInt(Length(FBuf)) + ACount + (SizeUInt(Length(FBuf)) shr 1));
  end;
end;

procedure TsshWriter.Clear;
begin
  FLen := 0;
end;

function TsshWriter.Count: SizeUInt;
begin
  Result := FLen;
end;

function TsshWriter.ToBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(FBuf[0], Result[0], FLen);
end;

procedure TsshWriter.PutByte(AValue: Byte);
begin
  Ensure(1);
  FBuf[FLen] := AValue;
  Inc(FLen);
end;

procedure TsshWriter.PutBoolean(AValue: Boolean);
begin
  PutByte(Ord(AValue));
end;

procedure TsshWriter.PutUInt32(AValue: UInt32);
begin
  Ensure(4);
  FBuf[FLen] := Byte(AValue shr 24);
  FBuf[FLen + 1] := Byte((AValue shr 16) and $FF);
  FBuf[FLen + 2] := Byte((AValue shr 8) and $FF);
  FBuf[FLen + 3] := Byte(AValue and $FF);
  Inc(FLen, 4);
end;

procedure TsshWriter.PutStringBytes(const AValue: TBytes);
begin
  PutUInt32(UInt32(Length(AValue)));
  PutRaw(AValue);
end;

procedure TsshWriter.PutStringText(const AText: string);
begin
  PutUInt32(UInt32(Length(AText)));
  if Length(AText) > 0 then
    PutRaw(PByte(Pointer(AText)), SizeUInt(Length(AText)));
end;

procedure TsshWriter.PutMPInt(const AMagnitude: TBytes);
var
  LStart: SizeUInt;
  LMagLen: SizeUInt;
begin
  LStart := 0;
  while (LStart < SizeUInt(Length(AMagnitude))) and (AMagnitude[LStart] = 0) do
    Inc(LStart);
  LMagLen := SizeUInt(Length(AMagnitude)) - LStart;
  if LMagLen = 0 then
  begin
    PutUInt32(0);
    Exit;
  end;
  if (AMagnitude[LStart] and $80) <> 0 then
  begin
    PutUInt32(UInt32(LMagLen + 1));
    PutByte(0);
    PutRaw(@AMagnitude[LStart], LMagLen);
  end
  else
  begin
    PutUInt32(UInt32(LMagLen));
    PutRaw(@AMagnitude[LStart], LMagLen);
  end;
end;

procedure TsshWriter.PutNameList(const ANames: array of string);
var
  I: Integer;
  LJoined: string;
begin
  LJoined := '';
  for I := 0 to High(ANames) do
  begin
    if I > 0 then
      LJoined := LJoined + ',';
    LJoined := LJoined + ANames[I];
  end;
  PutStringText(LJoined);
end;

procedure TsshWriter.PutRaw(const APtr: PByte; ALen: SizeUInt);
begin
  if ALen = 0 then
    Exit;
  Ensure(ALen);
  Move(APtr^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TsshWriter.PutRaw(const AValue: TBytes);
begin
  if Length(AValue) > 0 then
    PutRaw(@AValue[0], SizeUInt(Length(AValue)));
end;

{ TsshReader }

constructor TsshReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
end;

procedure TsshReader.Need(ACount: SizeUInt);
begin
  if Remaining < ACount then
    raise ESSHError.Create(sekProtocol,
      'ssh buffer: truncated payload (need ' + IntToStr(ACount) +
      ', remaining ' + IntToStr(Remaining) + ')');
end;

function TsshReader.AtEnd: Boolean;
begin
  Result := FPos >= SizeUInt(Length(FData));
end;

function TsshReader.Remaining: SizeUInt;
begin
  Result := SizeUInt(Length(FData)) - FPos;
end;

function TsshReader.Position: SizeUInt;
begin
  Result := FPos;
end;

function TsshReader.PeekByte: Byte;
begin
  Need(1);
  Result := FData[FPos];
end;

function TsshReader.ReadByte: Byte;
begin
  Need(1);
  Result := FData[FPos];
  Inc(FPos);
end;

procedure TsshReader.Skip(ACount: SizeUInt);
begin
  Need(ACount);
  Inc(FPos, ACount);
end;

function TsshReader.ReadBoolean: Boolean;
begin
  Result := ReadByte <> 0;
end;

function TsshReader.ReadUInt32: UInt32;
begin
  Need(4);
  Result := (UInt32(FData[FPos]) shl 24)
    or (UInt32(FData[FPos + 1]) shl 16)
    or (UInt32(FData[FPos + 2]) shl 8)
    or UInt32(FData[FPos + 3]);
  Inc(FPos, 4);
end;

procedure TsshWriter.PutUInt64(AValue: UInt64);
begin
  PutUInt32(UInt32(AValue shr 32));
  PutUInt32(UInt32(AValue and $FFFFFFFF));
end;

function TsshReader.ReadUInt64: UInt64;
begin
  Result := (UInt64(ReadUInt32) shl 32) or UInt64(ReadUInt32);
end;

function TsshReader.ReadStringBytes: TBytes;
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

function TsshReader.ReadStringText: string;
begin
  Result := SshTextFromBytes(ReadStringBytes);
end;

function TsshReader.ReadMPInt: TBytes;
var
  LBlob: TBytes;
  LO: SizeUInt;
begin
  LBlob := ReadStringBytes;
  Result := nil;
  LO := 0;
  while (LO < SizeUInt(Length(LBlob))) and (LBlob[LO] = 0) do
    Inc(LO);
  SetLength(Result, SizeUInt(Length(LBlob)) - LO);
  if SizeUInt(Length(LBlob)) > LO then
    Move(LBlob[LO], Result[0], SizeUInt(Length(LBlob)) - LO);
end;

function TsshReader.ReadNameList: TStringArray;
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
