unit nextpas.core.zip.writer;
{**
 * @desc ZIP 归档写器实现：local file header + central directory + EOCD，
 *       支持 store 与 deflate（method=8，经 compress.RawDeflate）条目，
 *       以及目录条目。产出任何标准解压器可直接读取的归档。
 *
 * 确定性：未指定时间戳取 DOS 纪元下限，同输入同字节；deflate 载荷由 zlib
 * 版本决定，跨环境不保证字节一致，但始终可被标准解压器还原。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder,
  nextpas.core.zip.base;

type
  {** @desc ZIP 归档写器（store/deflate 条目，顺序追加，Finish 一次性终结） *}
  IZipWriter = interface
    ['{E7A14F63-52C9-4B0D-9E28-3F6D1A95C7B4}']
    {** 添加 store 条目；时间戳取 DOS 下限（确定性输出） *}
    procedure AddEntry(const AName: string; const AData: TBytes);
    {** 添加 store 条目，AModTimeUnixSec 为 unix 秒（越界钳制到 DOS 区间） *}
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 添加 deflate(method=8) 条目；时间戳取 DOS 下限 *}
    procedure AddEntryDeflate(const AName: string; const AData: TBytes);
    {** 添加 deflate 条目，显式 unix 秒时间戳 *}
    procedure AddEntryDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 添加目录条目：名字规范化补尾随 '/'，零载荷，目录外部属性 *}
    procedure AddDirectory(const AName: string);
    {** 同上，显式 unix 秒时间戳 *}
    procedure AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64);
    {** 已添加条目数 *}
    function EntryCount: Integer;
    {** 终结并返回完整归档字节；此后各添加方法与 Finish 均 raise *}
    function Finish: TBytes;
  end;

function NewZipWriter: IZipWriter;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate;

type
  TZipEntryMeta = record
    FName: string;        { UTF-8 字节序列（Pascal string 直存） }
    FMethod: Word;
    FCrc: LongWord;       { 未压缩载荷的 CRC32 }
    FUSize: LongWord;     { 未压缩尺寸 }
    FCSize: LongWord;     { 压缩后尺寸（store 时等于 FUSize） }
    FDosTime: Word;
    FDosDate: Word;
    FLocalOffset: LongWord;
    FIsDir: Boolean;
  end;

  TZipWriter = class(TInterfacedObject, IZipWriter)
  private
    FOut: IBytesBuilder;
    FEntries: array of TZipEntryMeta;
    FFinished: Boolean;
    procedure CheckOpen;
    procedure AddEntryInternal(const AName: string; const APayload,
      AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
      AIsDir: Boolean);
    procedure AddDirectoryInternal(const AName: string;
      const AModTimeUnixSec: Int64);
  public
    constructor Create;
    procedure AddEntry(const AName: string; const AData: TBytes);
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    procedure AddEntryDeflate(const AName: string; const AData: TBytes);
    procedure AddEntryDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    procedure AddDirectory(const AName: string);
    procedure AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64);
    function EntryCount: Integer;
    function Finish: TBytes;
  end;

function NewZipWriter: IZipWriter;
begin
  Result := TZipWriter.Create;
end;

constructor TZipWriter.Create;
begin
  inherited Create;
  FOut := CreateBytesBuilder(256);
  FFinished := False;
end;

procedure TZipWriter.CheckOpen;
begin
  if FFinished then
    raise EInvalidOperationError.Create('zip writer already finished');
end;

procedure TZipWriter.AddEntryInternal(const AName: string; const APayload,
  AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
  AIsDir: Boolean);
var
  LCrc: LongWord;
  LUSize, LCSize: LongWord;
  LDosDate, LDosTime: Word;
  LMeta: TZipEntryMeta;
begin
  CheckOpen;
  ValidateZipEntryName(AName);
  if Length(FEntries) >= C_ZIP_MAX_ENTRIES32 then
    raise EInvalidOperationError.Create('zip writer: entry count exceeds ZIP32 limit (' +
      IntToStr(C_ZIP_MAX_ENTRIES32) + ')');
  if SizeUInt(Length(APayload)) > C_ZIP_MAX_SIZE32 then
    raise EInvalidOperationError.Create('zip writer: entry size exceeds ZIP32 limit (4 GiB)');
  { 本地头 30 字节 + 名长 + 载荷长必须仍落在 4 GiB 内，保证 central dir 偏移不溢出 }
  if (Int64(FOut.Length) + 30 + Length(AName) + Length(APayload)) > Int64(C_ZIP_MAX_SIZE32) then
    raise EInvalidOperationError.Create('zip writer: archive size exceeds ZIP32 limit (4 GiB)');

  LUSize := LongWord(Length(AData));
  LCSize := LongWord(Length(APayload));
  LCrc := Crc32OfBytes(AData);
  DosDateTimeFromUnix(AModTimeUnixSec, LDosDate, LDosTime);

  LMeta.FName := AName;
  LMeta.FMethod := AMethod;
  LMeta.FCrc := LCrc;
  LMeta.FUSize := LUSize;
  LMeta.FCSize := LCSize;
  LMeta.FDosTime := LDosTime;
  LMeta.FDosDate := LDosDate;
  LMeta.FLocalOffset := LongWord(FOut.Length);
  LMeta.FIsDir := AIsDir;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LMeta;

  FOut.AppendUInt32LE(C_ZIP_LOCAL_SIG);
  FOut.AppendUInt16LE(C_ZIP_VERSION_DEFAULT);
  FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
  FOut.AppendUInt16LE(AMethod);
  FOut.AppendUInt16LE(LDosTime);
  FOut.AppendUInt16LE(LDosDate);
  FOut.AppendUInt32LE(LCrc);
  FOut.AppendUInt32LE(LCSize);
  FOut.AppendUInt32LE(LUSize);
  FOut.AppendUInt16LE(Word(Length(AName)));
  FOut.AppendUInt16LE(0);
  if Length(AName) > 0 then
    FOut.AppendBytes(PByte(Pointer(AName)), Length(AName));
  if Length(APayload) > 0 then
    FOut.AppendBytes(PByte(APayload), LCSize);
end;

procedure TZipWriter.AddEntry(const AName: string; const AData: TBytes);
begin
  { DOS 纪元下限：确定性输出（同输入同字节），见单元头注释 }
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, DosMinUnixSec,
    False);
end;

procedure TZipWriter.AddEntryWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64);
begin
  AddEntryInternal(AName, AData, AData, C_ZIP_METHOD_STORE, AModTimeUnixSec,
    False);
end;

procedure TZipWriter.AddEntryDeflate(const AName: string; const AData: TBytes);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    DosMinUnixSec, False);
end;

procedure TZipWriter.AddEntryDeflateWithTime(const AName: string;
  const AData: TBytes; const AModTimeUnixSec: Int64);
var
  LPayload: TBytes;
begin
  LPayload := RawDeflateCompress(AData);
  AddEntryInternal(AName, LPayload, AData, C_ZIP_METHOD_DEFLATE,
    AModTimeUnixSec, False);
end;

procedure TZipWriter.AddDirectory(const AName: string);
begin
  AddDirectoryInternal(AName, DosMinUnixSec);
end;

procedure TZipWriter.AddDirectoryWithTime(const AName: string;
  const AModTimeUnixSec: Int64);
begin
  AddDirectoryInternal(AName, AModTimeUnixSec);
end;

procedure TZipWriter.AddDirectoryInternal(const AName: string;
  const AModTimeUnixSec: Int64);
var
  LNorm: string;
begin
  LNorm := AName;
  if (LNorm <> '') and (LNorm[Length(LNorm)] <> '/') then
    LNorm := LNorm + '/';
  AddEntryInternal(LNorm, nil, nil, C_ZIP_METHOD_STORE, AModTimeUnixSec, True);
end;

function TZipWriter.EntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TZipWriter.Finish: TBytes;
var
  LI: Integer;
  LCDOffset, LCDEnd: LongWord;
  LE: TZipEntryMeta;
begin
  CheckOpen;
  LCDOffset := LongWord(FOut.Length);
  for LI := 0 to High(FEntries) do
  begin
    LE := FEntries[LI];
    FOut.AppendUInt32LE(C_ZIP_CENTRAL_SIG);
    FOut.AppendUInt16LE(C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_DEFAULT);
    FOut.AppendUInt16LE(C_ZIP_VERSION_DEFAULT);
    FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
    FOut.AppendUInt16LE(Word(LE.FMethod));
    FOut.AppendUInt16LE(LE.FDosTime);
    FOut.AppendUInt16LE(LE.FDosDate);
    FOut.AppendUInt32LE(LE.FCrc);
    FOut.AppendUInt32LE(LE.FCSize);
    FOut.AppendUInt32LE(LE.FUSize);
    FOut.AppendUInt16LE(Word(Length(LE.FName)));
    FOut.AppendUInt16LE(0);  { extra len }
    FOut.AppendUInt16LE(0);  { comment len }
    FOut.AppendUInt16LE(0);  { disk number start }
    FOut.AppendUInt16LE(0);  { internal attrs }
    if LE.FIsDir then
      FOut.AppendUInt32LE(C_ZIP_EXTERNAL_ATTR_DIRECTORY)
    else
      FOut.AppendUInt32LE(C_ZIP_EXTERNAL_ATTR_REGULAR);
    FOut.AppendUInt32LE(LE.FLocalOffset);
    if Length(LE.FName) > 0 then
      FOut.AppendBytes(PByte(Pointer(LE.FName)), Length(LE.FName));
  end;
  { central 尺寸必须在写 EOCD 前固化，否则会把 EOCD 自身前缀计入 }
  LCDEnd := LongWord(FOut.Length);
  FOut.AppendUInt32LE(C_ZIP_EOCD_SIG);
  FOut.AppendUInt16LE(0);  { 本盘号 }
  FOut.AppendUInt16LE(0);  { central dir 起始盘号 }
  FOut.AppendUInt16LE(Word(Length(FEntries)));
  FOut.AppendUInt16LE(Word(Length(FEntries)));
  FOut.AppendUInt32LE(LCDEnd - LCDOffset);
  FOut.AppendUInt32LE(LCDOffset);
  FOut.AppendUInt16LE(0);  { 注释长 }
  FFinished := True;
  Result := FOut.ToBytes;
end;

end.
