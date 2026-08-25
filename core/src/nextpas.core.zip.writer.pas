unit nextpas.core.zip.writer;
{**
 * @desc ZIP 归档写器实现：local file header + central directory + EOCD，
 *       支持 store 与 deflate（method=8，经 compress.RawDeflate）条目、
 *       目录条目，以及 Zip64：尺寸/偏移/条目数超 ZIP32 宽度时自动启用，
 *       TZipWriteOptions.ForceZip64 可无条件强制。产出任何标准解压器可读的归档。
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
  {** @desc 写选项：ForceZip64 无条件产出 Zip64 结构（预知超大归档/测试用） *}
  TZipWriteOptions = record
    ForceZip64: Boolean;
  end;

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

{** 默认写选项。 *}
function DefaultZipWriteOptions: TZipWriteOptions; inline;

function NewZipWriter: IZipWriter;

{** 带选项构造。 *}
function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.compress.deflate;

const
  C_ZIP64_LOCAL_EXTRA_LEN = 20;  { id(2)+size(2)+原始/压缩尺寸各 8 }
  C_ZIP64_EOCD_BODY_LEN   = 44;  { zip64 EOCD 记录体（不含签名+尺寸前缀 12 字节） }

type
  TZipEntryMeta = record
    FName: string;        { UTF-8 字节序列（Pascal string 直存） }
    FMethod: Word;
    FCrc: LongWord;       { 未压缩载荷的 CRC32 }
    FUSize: UInt64;       { 未压缩尺寸 }
    FCSize: UInt64;       { 压缩后尺寸（store 时等于 FUSize） }
    FDosTime: Word;
    FDosDate: Word;
    FLocalOffset: UInt64;
    FIsDir: Boolean;
    FNeedsZ64Sizes: Boolean;  { 尺寸走 Zip64 extra（含 Force 场景） }
  end;

  TZipWriter = class(TInterfacedObject, IZipWriter)
  private
    FOut: IBytesBuilder;
    FEntries: array of TZipEntryMeta;
    FFinished: Boolean;
    FForceZip64: Boolean;
    procedure CheckOpen;
    procedure AddEntryInternal(const AName: string; const APayload,
      AData: TBytes; AMethod: Word; const AModTimeUnixSec: Int64;
      AIsDir: Boolean);
    procedure AddDirectoryInternal(const AName: string;
      const AModTimeUnixSec: Int64);
  public
    constructor Create(AForceZip64: Boolean);
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

function DefaultZipWriteOptions: TZipWriteOptions;
begin
  Result.ForceZip64 := False;
end;

function NewZipWriter: IZipWriter;
begin
  Result := NewZipWriterWithOptions(DefaultZipWriteOptions);
end;

function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter;
begin
  Result := TZipWriter.Create(AOptions.ForceZip64);
end;

constructor TZipWriter.Create(AForceZip64: Boolean);
begin
  inherited Create;
  FOut := CreateBytesBuilder(256);
  FFinished := False;
  FForceZip64 := AForceZip64;
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
  LDosDate, LDosTime: Word;
  LMeta: TZipEntryMeta;
  LVersion: Word;
begin
  CheckOpen;
  ValidateZipEntryName(AName);

  LMeta.FNeedsZ64Sizes := FForceZip64 or
    (UInt64(Length(AData)) > C_ZIP_MAX_SIZE32) or
    (UInt64(Length(APayload)) > C_ZIP_MAX_SIZE32);

  LCrc := Crc32OfBytes(AData);
  DosDateTimeFromUnix(AModTimeUnixSec, LDosDate, LDosTime);

  LMeta.FName := AName;
  LMeta.FMethod := AMethod;
  LMeta.FCrc := LCrc;
  LMeta.FUSize := Length(AData);
  LMeta.FCSize := Length(APayload);
  LMeta.FDosTime := LDosTime;
  LMeta.FDosDate := LDosDate;
  LMeta.FLocalOffset := FOut.Length;
  LMeta.FIsDir := AIsDir;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LMeta;

  if LMeta.FNeedsZ64Sizes then
    LVersion := C_ZIP_VERSION_ZIP64
  else
    LVersion := C_ZIP_VERSION_DEFAULT;

  FOut.AppendUInt32LE(C_ZIP_LOCAL_SIG);
  FOut.AppendUInt16LE(LVersion);
  FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
  FOut.AppendUInt16LE(AMethod);
  FOut.AppendUInt16LE(LDosTime);
  FOut.AppendUInt16LE(LDosDate);
  FOut.AppendUInt32LE(LCrc);
  if LMeta.FNeedsZ64Sizes then
  begin
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);  { 实际值在 Zip64 extra }
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
  end
  else
  begin
    FOut.AppendUInt32LE(LongWord(Length(APayload)));
    FOut.AppendUInt32LE(LongWord(Length(AData)));
  end;
  FOut.AppendUInt16LE(Word(Length(AName)));
  if LMeta.FNeedsZ64Sizes then
    FOut.AppendUInt16LE(C_ZIP64_LOCAL_EXTRA_LEN)
  else
    FOut.AppendUInt16LE(0);
  if Length(AName) > 0 then
    FOut.AppendBytes(PByte(Pointer(AName)), Length(AName));
  if LMeta.FNeedsZ64Sizes then
  begin
    FOut.AppendUInt16LE(C_ZIP64_EXTRA_ID);
    FOut.AppendUInt16LE(16);
    FOut.AppendUInt64LE(LMeta.FUSize);
    FOut.AppendUInt64LE(LMeta.FCSize);
  end;
  if Length(APayload) > 0 then
    FOut.AppendBytes(PByte(APayload), Length(APayload));
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
  LE: TZipEntryMeta;
  LCDOffset, LCDSize, LCDEnd, LZ64EocdPos: UInt64;
  LCount: Int64;
  LNeedsZ64Offset, LAnyZ64, LNeedZ64Eocd: Boolean;
  LVersionMadeBy, LVersionNeeded: Word;
  LExtraLen: Integer;
  LCountField: LongWord;
begin
  CheckOpen;
  LCDOffset := FOut.Length;
  for LI := 0 to High(FEntries) do
  begin
    LE := FEntries[LI];
    LNeedsZ64Offset := FForceZip64 or (LE.FLocalOffset > C_ZIP_MAX_SIZE32);
    LAnyZ64 := LE.FNeedsZ64Sizes or LNeedsZ64Offset;
    if LAnyZ64 then
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64;
      LVersionNeeded := C_ZIP_VERSION_ZIP64;
    end
    else
    begin
      LVersionMadeBy := C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_DEFAULT;
      LVersionNeeded := C_ZIP_VERSION_DEFAULT;
    end;

    FOut.AppendUInt32LE(C_ZIP_CENTRAL_SIG);
    FOut.AppendUInt16LE(LVersionMadeBy);
    FOut.AppendUInt16LE(LVersionNeeded);
    FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
    FOut.AppendUInt16LE(LE.FMethod);
    FOut.AppendUInt16LE(LE.FDosTime);
    FOut.AppendUInt16LE(LE.FDosDate);
    FOut.AppendUInt32LE(LE.FCrc);
    if LE.FNeedsZ64Sizes then
    begin
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32);
    end
    else
    begin
      FOut.AppendUInt32LE(LongWord(LE.FCSize));
      FOut.AppendUInt32LE(LongWord(LE.FUSize));
    end;
    FOut.AppendUInt16LE(Word(Length(LE.FName)));
    LExtraLen := 0;
    if LE.FNeedsZ64Sizes then
      Inc(LExtraLen, 16);
    if LNeedsZ64Offset then
      Inc(LExtraLen, 8);
    if LExtraLen > 0 then
      FOut.AppendUInt16LE(Word(LExtraLen + 4))
    else
      FOut.AppendUInt16LE(0);
    FOut.AppendUInt16LE(0);  { comment len }
    FOut.AppendUInt16LE(0);  { disk number start }
    FOut.AppendUInt16LE(0);  { internal attrs }
    if LE.FIsDir then
      FOut.AppendUInt32LE(C_ZIP_EXTERNAL_ATTR_DIRECTORY)
    else
      FOut.AppendUInt32LE(C_ZIP_EXTERNAL_ATTR_REGULAR);
    if LNeedsZ64Offset then
      FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
    else
      FOut.AppendUInt32LE(LongWord(LE.FLocalOffset));
    { central 布局固定顺序：固定字段、文件名、extra、注释 }
    if Length(LE.FName) > 0 then
      FOut.AppendBytes(PByte(Pointer(LE.FName)), Length(LE.FName));
    if LExtraLen > 0 then
    begin
      FOut.AppendUInt16LE(C_ZIP64_EXTRA_ID);
      FOut.AppendUInt16LE(Word(LExtraLen));
      { APPNOTE 固定顺序：原始尺寸、压缩尺寸、本地头偏移 }
      if LE.FNeedsZ64Sizes then
      begin
        FOut.AppendUInt64LE(LE.FUSize);
        FOut.AppendUInt64LE(LE.FCSize);
      end;
      if LNeedsZ64Offset then
        FOut.AppendUInt64LE(LE.FLocalOffset);
    end;
  end;

  { central 尺寸必须在写 EOCD 前固化，否则会把 EOCD 自身前缀计入 }
  LCDEnd := FOut.Length;
  LCDSize := LCDEnd - LCDOffset;
  LCount := Length(FEntries);

  LNeedZ64Eocd := FForceZip64 or (LCount > C_ZIP_MAX_ENTRIES32) or
    (LCDSize > C_ZIP_MAX_SIZE32) or (LCDOffset > C_ZIP_MAX_SIZE32);
  if LNeedZ64Eocd then
  begin
    LZ64EocdPos := FOut.Length;
    FOut.AppendUInt32LE(C_ZIP64_EOCD_SIG);
    FOut.AppendUInt64LE(C_ZIP64_EOCD_BODY_LEN);
    FOut.AppendUInt16LE(C_ZIP_MADE_BY_HOST_UNIX or C_ZIP_VERSION_ZIP64);
    FOut.AppendUInt16LE(C_ZIP_VERSION_ZIP64);
    FOut.AppendUInt32LE(0);                  { 本盘号 }
    FOut.AppendUInt32LE(0);                  { central dir 起始盘号 }
    FOut.AppendUInt64LE(UInt64(LCount));     { 本盘条目数 }
    FOut.AppendUInt64LE(UInt64(LCount));     { 总条目数 }
    FOut.AppendUInt64LE(LCDSize);
    FOut.AppendUInt64LE(LCDOffset);
    FOut.AppendUInt32LE(C_ZIP64_EOCD_LOC_SIG);
    FOut.AppendUInt32LE(0);                  { 本盘号 }
    FOut.AppendUInt64LE(LZ64EocdPos);        { zip64 EOCD 偏移 }
    FOut.AppendUInt32LE(1);                  { 总盘数 }
  end;

  FOut.AppendUInt32LE(C_ZIP_EOCD_SIG);
  FOut.AppendUInt16LE(0);  { 本盘号 }
  FOut.AppendUInt16LE(0);  { central dir 起始盘号 }
  if LCount > C_ZIP_MAX_ENTRIES32 then
    LCountField := $FFFF
  else
    LCountField := LongWord(LCount);
  FOut.AppendUInt16LE(Word(LCountField));
  FOut.AppendUInt16LE(Word(LCountField));
  if LCDSize > C_ZIP_MAX_SIZE32 then
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
  else
    FOut.AppendUInt32LE(LongWord(LCDSize));
  if LCDOffset > C_ZIP_MAX_SIZE32 then
    FOut.AppendUInt32LE(C_ZIP_MAX_SIZE32)
  else
    FOut.AppendUInt32LE(LongWord(LCDOffset));
  FOut.AppendUInt16LE(0);  { 注释长 }
  FFinished := True;
  Result := FOut.ToBytes;
end;

end.
