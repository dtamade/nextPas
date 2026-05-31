unit nextpas.core.io.binary;
{ Typed binary reader/writer over IReader/IWriter.
  Provides structured access to binary streams with explicit endianness.
  Raises EIOError on unexpected EOF or write failure (never silently truncates).

  Usage:
    var R: TBinaryReader;
    R.Init(MyStream);
    LVersion := R.ReadUInt32LE;
    LName := R.ReadString(R.ReadUInt16LE); }

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf;

const
  BINARY_MAX_ALLOC = SizeUInt(64 * 1024 * 1024);

type
  TBinaryReader = record
  private
    FReader: IReader;
  public
    procedure Init(const AReader: IReader);
    function ReadUInt8: Byte;
    function ReadInt8: ShortInt;
    function ReadUInt16LE: UInt16;
    function ReadUInt16BE: UInt16;
    function ReadInt16LE: Int16;
    function ReadInt16BE: Int16;
    function ReadUInt32LE: UInt32;
    function ReadUInt32BE: UInt32;
    function ReadInt32LE: Int32;
    function ReadInt32BE: Int32;
    function ReadUInt64LE: UInt64;
    function ReadUInt64BE: UInt64;
    function ReadInt64LE: Int64;
    function ReadInt64BE: Int64;
    function ReadFloat32LE: Single;
    function ReadFloat64LE: Double;
    function ReadBytes(ACount: SizeUInt): TBytes;
    function ReadString(ALen: SizeUInt): string;
    function ReadBool: Boolean;
  end;

  TBinaryWriter = record
  private
    FWriter: IWriter;
  public
    procedure Init(const AWriter: IWriter);
    procedure WriteUInt8(AValue: Byte);
    procedure WriteInt8(AValue: ShortInt);
    procedure WriteUInt16LE(AValue: UInt16);
    procedure WriteUInt16BE(AValue: UInt16);
    procedure WriteInt16LE(AValue: Int16);
    procedure WriteInt16BE(AValue: Int16);
    procedure WriteUInt32LE(AValue: UInt32);
    procedure WriteUInt32BE(AValue: UInt32);
    procedure WriteInt32LE(AValue: Int32);
    procedure WriteInt32BE(AValue: Int32);
    procedure WriteUInt64LE(AValue: UInt64);
    procedure WriteUInt64BE(AValue: UInt64);
    procedure WriteInt64LE(AValue: Int64);
    procedure WriteInt64BE(AValue: Int64);
    procedure WriteFloat32LE(AValue: Single);
    procedure WriteFloat64LE(AValue: Double);
    procedure WriteBytes(const AData: TBytes);
    procedure WriteBytesRaw(const AData: PByte; ALen: SizeUInt);
    procedure WriteString(const AValue: string);
    procedure WriteBool(AValue: Boolean);
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.io.util;

function SwapU16(V: UInt16): UInt16; inline;
begin
  Result := (V shr 8) or (V shl 8);
end;

function SwapU32(V: UInt32): UInt32; inline;
begin
  Result := ((V and $FF000000) shr 24) or ((V and $00FF0000) shr 8) or
            ((V and $0000FF00) shl 8) or ((V and $000000FF) shl 24);
end;

function SwapU64(V: UInt64): UInt64; inline;
begin
  Result := ((V and QWord($FF00000000000000)) shr 56) or
            ((V and QWord($00FF000000000000)) shr 40) or
            ((V and QWord($0000FF0000000000)) shr 24) or
            ((V and QWord($000000FF00000000)) shr 8) or
            ((V and QWord($00000000FF000000)) shl 8) or
            ((V and QWord($0000000000FF0000)) shl 24) or
            ((V and QWord($000000000000FF00)) shl 40) or
            ((V and QWord($00000000000000FF)) shl 56);
end;

procedure WriteAll(const AWriter: IWriter; const ABuf; ACount: SizeUInt);
var
  LWritten, LTotal: SizeUInt;
  LPtr: PByte;
begin
  LPtr := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LWritten := AWriter.Write(LPtr[LTotal], ACount - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('BinaryWriter: write failed (zero progress)');
    Inc(LTotal, LWritten);
  end;
end;

{ TBinaryReader }

procedure TBinaryReader.Init(const AReader: IReader);
begin
  if AReader = nil then
    raise EArgumentError.Create('TBinaryReader.Init: AReader is nil');
  FReader := AReader;
end;

function TBinaryReader.ReadUInt8: Byte;
begin
  Result := 0;
  IoReadFull(FReader, Result, 1);
end;

function TBinaryReader.ReadInt8: ShortInt;
begin
  Result := 0;
  IoReadFull(FReader, Result, 1);
end;

function TBinaryReader.ReadUInt16LE: UInt16;
begin
  Result := 0;
  IoReadFull(FReader, Result, 2);
{$IFDEF ENDIAN_BIG} Result := SwapU16(Result); {$ENDIF}
end;

function TBinaryReader.ReadUInt16BE: UInt16;
begin
  Result := 0;
  IoReadFull(FReader, Result, 2);
{$IFNDEF ENDIAN_BIG} Result := SwapU16(Result); {$ENDIF}
end;

function TBinaryReader.ReadInt16LE: Int16;
begin Result := Int16(ReadUInt16LE); end;

function TBinaryReader.ReadInt16BE: Int16;
begin Result := Int16(ReadUInt16BE); end;

function TBinaryReader.ReadUInt32LE: UInt32;
begin
  Result := 0;
  IoReadFull(FReader, Result, 4);
{$IFDEF ENDIAN_BIG} Result := SwapU32(Result); {$ENDIF}
end;

function TBinaryReader.ReadUInt32BE: UInt32;
begin
  Result := 0;
  IoReadFull(FReader, Result, 4);
{$IFNDEF ENDIAN_BIG} Result := SwapU32(Result); {$ENDIF}
end;

function TBinaryReader.ReadInt32LE: Int32;
begin Result := Int32(ReadUInt32LE); end;

function TBinaryReader.ReadInt32BE: Int32;
begin Result := Int32(ReadUInt32BE); end;

function TBinaryReader.ReadUInt64LE: UInt64;
begin
  Result := 0;
  IoReadFull(FReader, Result, 8);
{$IFDEF ENDIAN_BIG} Result := SwapU64(Result); {$ENDIF}
end;

function TBinaryReader.ReadUInt64BE: UInt64;
begin
  Result := 0;
  IoReadFull(FReader, Result, 8);
{$IFNDEF ENDIAN_BIG} Result := SwapU64(Result); {$ENDIF}
end;

function TBinaryReader.ReadInt64LE: Int64;
begin Result := Int64(ReadUInt64LE); end;

function TBinaryReader.ReadInt64BE: Int64;
begin Result := Int64(ReadUInt64BE); end;

function TBinaryReader.ReadFloat32LE: Single;
var LBits: UInt32;
begin
  LBits := ReadUInt32LE;
  Move(LBits, Result, 4);
end;

function TBinaryReader.ReadFloat64LE: Double;
var LBits: UInt64;
begin
  LBits := ReadUInt64LE;
  Move(LBits, Result, 8);
end;

function TBinaryReader.ReadBytes(ACount: SizeUInt): TBytes;
begin
  Result := nil;
  if ACount = 0 then Exit;
  if ACount > BINARY_MAX_ALLOC then
    raise EIOError.Create('BinaryReader: requested allocation exceeds limit');
  SetLength(Result, ACount);
  IoReadFull(FReader, Result[0], ACount);
end;

function TBinaryReader.ReadString(ALen: SizeUInt): string;
begin
  Result := '';
  if ALen = 0 then Exit;
  if ALen > BINARY_MAX_ALLOC then
    raise EIOError.Create('BinaryReader: requested allocation exceeds limit');
  SetLength(Result, ALen);
  IoReadFull(FReader, Result[1], ALen);
end;

function TBinaryReader.ReadBool: Boolean;
begin Result := ReadUInt8 <> 0; end;

{ TBinaryWriter }

procedure TBinaryWriter.Init(const AWriter: IWriter);
begin
  if AWriter = nil then
    raise EArgumentError.Create('TBinaryWriter.Init: AWriter is nil');
  FWriter := AWriter;
end;

procedure TBinaryWriter.WriteUInt8(AValue: Byte);
begin WriteAll(FWriter, AValue, 1); end;

procedure TBinaryWriter.WriteInt8(AValue: ShortInt);
begin WriteAll(FWriter, AValue, 1); end;

procedure TBinaryWriter.WriteUInt16LE(AValue: UInt16);
begin
{$IFDEF ENDIAN_BIG} AValue := SwapU16(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 2);
end;

procedure TBinaryWriter.WriteUInt16BE(AValue: UInt16);
begin
{$IFNDEF ENDIAN_BIG} AValue := SwapU16(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 2);
end;

procedure TBinaryWriter.WriteInt16LE(AValue: Int16);
begin WriteUInt16LE(UInt16(AValue)); end;

procedure TBinaryWriter.WriteInt16BE(AValue: Int16);
begin WriteUInt16BE(UInt16(AValue)); end;

procedure TBinaryWriter.WriteUInt32LE(AValue: UInt32);
begin
{$IFDEF ENDIAN_BIG} AValue := SwapU32(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 4);
end;

procedure TBinaryWriter.WriteUInt32BE(AValue: UInt32);
begin
{$IFNDEF ENDIAN_BIG} AValue := SwapU32(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 4);
end;

procedure TBinaryWriter.WriteInt32LE(AValue: Int32);
begin WriteUInt32LE(UInt32(AValue)); end;

procedure TBinaryWriter.WriteInt32BE(AValue: Int32);
begin WriteUInt32BE(UInt32(AValue)); end;

procedure TBinaryWriter.WriteUInt64LE(AValue: UInt64);
begin
{$IFDEF ENDIAN_BIG} AValue := SwapU64(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 8);
end;

procedure TBinaryWriter.WriteUInt64BE(AValue: UInt64);
begin
{$IFNDEF ENDIAN_BIG} AValue := SwapU64(AValue); {$ENDIF}
  WriteAll(FWriter, AValue, 8);
end;

procedure TBinaryWriter.WriteInt64LE(AValue: Int64);
begin WriteUInt64LE(UInt64(AValue)); end;

procedure TBinaryWriter.WriteInt64BE(AValue: Int64);
begin WriteUInt64BE(UInt64(AValue)); end;

procedure TBinaryWriter.WriteFloat32LE(AValue: Single);
var LBits: UInt32;
begin Move(AValue, LBits, 4); WriteUInt32LE(LBits); end;

procedure TBinaryWriter.WriteFloat64LE(AValue: Double);
var LBits: UInt64;
begin Move(AValue, LBits, 8); WriteUInt64LE(LBits); end;

procedure TBinaryWriter.WriteBytes(const AData: TBytes);
begin
  if Length(AData) > 0 then
    WriteAll(FWriter, AData[0], SizeUInt(Length(AData)));
end;

procedure TBinaryWriter.WriteBytesRaw(const AData: PByte; ALen: SizeUInt);
begin
  if ALen = 0 then Exit;
  if AData = nil then
    raise EArgumentError.Create('WriteBytesRaw: AData is nil with ALen > 0');
  WriteAll(FWriter, AData^, ALen);
end;

procedure TBinaryWriter.WriteString(const AValue: string);
begin
  if Length(AValue) > 0 then
    WriteAll(FWriter, AValue[1], SizeUInt(Length(AValue)));
end;

procedure TBinaryWriter.WriteBool(AValue: Boolean);
begin
  if AValue then WriteUInt8(1) else WriteUInt8(0);
end;

end.
