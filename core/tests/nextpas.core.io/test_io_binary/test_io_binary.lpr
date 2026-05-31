program test_io_binary;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.binary,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestWriteReadUInt8;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteUInt8(0); W.WriteUInt8(255); W.WriteUInt8(42);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(0), Int64(R.ReadUInt8), '0');
  CheckEqual(Int64(255), Int64(R.ReadUInt8), '255');
  CheckEqual(Int64(42), Int64(R.ReadUInt8), '42');
end;

procedure TestWriteReadUInt16LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteUInt16LE(0); W.WriteUInt16LE(65535); W.WriteUInt16LE(1234);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(0), Int64(R.ReadUInt16LE), '0');
  CheckEqual(Int64(65535), Int64(R.ReadUInt16LE), '65535');
  CheckEqual(Int64(1234), Int64(R.ReadUInt16LE), '1234');
end;

procedure TestWriteReadUInt32LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteUInt32LE(0); W.WriteUInt32LE($DEADBEEF); W.WriteUInt32LE(123456789);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(0), Int64(R.ReadUInt32LE), '0');
  CheckEqual(Int64($DEADBEEF), Int64(R.ReadUInt32LE), 'DEADBEEF');
  CheckEqual(Int64(123456789), Int64(R.ReadUInt32LE), '123456789');
end;

procedure TestWriteReadInt32LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteInt32LE(-1); W.WriteInt32LE(0); W.WriteInt32LE(2147483647);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(-1), Int64(R.ReadInt32LE), '-1');
  CheckEqual(Int64(0), Int64(R.ReadInt32LE), '0');
  CheckEqual(Int64(2147483647), Int64(R.ReadInt32LE), 'max');
end;

procedure TestWriteReadInt64LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteInt64LE(-9223372036854775808); W.WriteInt64LE(9223372036854775807);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(-9223372036854775808), R.ReadInt64LE, 'min');
  CheckEqual(Int64(9223372036854775807), R.ReadInt64LE, 'max');
end;

procedure TestWriteReadFloat32LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
  LVal: Single;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteFloat32LE(3.14); W.WriteFloat32LE(-0.5);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  LVal := R.ReadFloat32LE;
  Check(Abs(LVal - 3.14) < 0.01, 'pi');
  LVal := R.ReadFloat32LE;
  Check(Abs(LVal - (-0.5)) < 0.001, '-0.5');
end;

procedure TestWriteReadFloat64LE;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
  LVal: Double;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteFloat64LE(3.141592653589793); W.WriteFloat64LE(-1.0e100);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  LVal := R.ReadFloat64LE;
  Check(Abs(LVal - 3.141592653589793) < 1e-10, 'pi64');
  LVal := R.ReadFloat64LE;
  Check(LVal < -9e99, '-1e100');
end;

procedure TestWriteReadBytes;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
  LData, LRead: TBytes;
  LI: Integer;
begin
  SetLength(LData, 256);
  for LI := 0 to 255 do LData[LI] := Byte(LI);
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteBytes(LData);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  LRead := R.ReadBytes(256);
  Check(Length(LRead) = 256, 'len 256');
  for LI := 0 to 255 do
    Check(LRead[LI] = Byte(LI), 'byte ' + IntToStr(LI));
end;

procedure TestWriteReadString;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteString('hello world');
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual('hello world', R.ReadString(11), 'hello world');
end;

procedure TestWriteReadBool;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteBool(True); W.WriteBool(False);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  Check(R.ReadBool = True, 'true');
  Check(R.ReadBool = False, 'false');
end;

procedure TestBigEndian;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter); W.WriteUInt16BE($1234); W.WriteUInt32BE($AABBCCDD);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64($1234), Int64(R.ReadUInt16BE), 'u16 BE');
  CheckEqual(Int64($AABBCCDD), Int64(R.ReadUInt32BE), 'u32 BE');
end;

procedure TestMixedTypes;
var
  LS: IStream;
  W: TBinaryWriter;
  R: TBinaryReader;
begin
  LS := CreateBytesStream;
  W.Init(LS as IWriter);
  W.WriteUInt8(1);
  W.WriteUInt32LE(42);
  W.WriteFloat64LE(2.718);
  W.WriteUInt16LE(5);
  W.WriteString('hello');
  W.WriteBool(True);
  LS.Seek(0, soBeginning);
  R.Init(LS as IReader);
  CheckEqual(Int64(1), Int64(R.ReadUInt8), 'version');
  CheckEqual(Int64(42), Int64(R.ReadUInt32LE), 'id');
  Check(Abs(R.ReadFloat64LE - 2.718) < 0.001, 'value');
  CheckEqual(Int64(5), Int64(R.ReadUInt16LE), 'name len');
  CheckEqual('hello', R.ReadString(5), 'name');
  Check(R.ReadBool, 'active');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.binary');
  T.Run('uint8', @TestWriteReadUInt8);
  T.Run('uint16 LE', @TestWriteReadUInt16LE);
  T.Run('uint32 LE', @TestWriteReadUInt32LE);
  T.Run('int32 LE', @TestWriteReadInt32LE);
  T.Run('int64 LE', @TestWriteReadInt64LE);
  T.Run('float32 LE', @TestWriteReadFloat32LE);
  T.Run('float64 LE', @TestWriteReadFloat64LE);
  T.Run('bytes', @TestWriteReadBytes);
  T.Run('string', @TestWriteReadString);
  T.Run('bool', @TestWriteReadBool);
  T.Run('big-endian', @TestBigEndian);
  T.Run('mixed types', @TestMixedTypes);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
