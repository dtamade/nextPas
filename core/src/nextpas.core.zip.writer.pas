unit nextpas.core.zip.writer;
{**
 * @desc ZIP 归档写器实现：local file header + central directory + EOCD，
 *       产出任何标准解压器可直接读取的归档。压缩方法与 Zip64 结构在此单元演进。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder,
  nextpas.core.zip.base;

type
  {** @desc ZIP 归档写器（顺序追加，Finish 一次性终结） *}
  IZipWriter = interface
    ['{D09A5E11-3F42-4C8B-9A17-6E2C80B41F33}']
    {** 添加 store 条目；时间戳取 DOS 下限（确定性输出） *}
    procedure AddEntry(const AName: string; const AData: TBytes);
    {** 添加 store 条目，AModTimeUnixSec 为 unix 秒（越界钳制到 DOS 区间） *}
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 已添加条目数 *}
    function EntryCount: Integer;
    {** 终结并返回完整归档字节；此后 AddEntry*/Finish 均 raise *}
    function Finish: TBytes;
  end;

function NewZipWriter: IZipWriter;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32;

type
  TZipEntryMeta = record
    FName: string;        { UTF-8 字节序列（Pascal string 直存） }
    FCrc: LongWord;
    FSize: LongWord;
    FDosTime: Word;
    FDosDate: Word;
    FLocalOffset: LongWord;
  end;

  TZipWriter = class(TInterfacedObject, IZipWriter)
  private
    FOut: IBytesBuilder;
    FEntries: array of TZipEntryMeta;
    FFinished: Boolean;
    procedure CheckOpen;
    procedure AddEntryInternal(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
  public
    constructor Create;
    procedure AddEntry(const AName: string; const AData: TBytes);
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
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

procedure TZipWriter.AddEntryInternal(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64);
var
  LCrc: LongWord;
  LSize: LongWord;
  LDosDate, LDosTime: Word;
  LMeta: TZipEntryMeta;
begin
  CheckOpen;
  ValidateZipEntryName(AName);
  if Length(FEntries) >= C_ZIP_MAX_ENTRIES32 then
    raise EInvalidOperationError.Create('zip writer: entry count exceeds ZIP32 limit (' +
      IntToStr(C_ZIP_MAX_ENTRIES32) + ')');
  if SizeUInt(Length(AData)) > C_ZIP_MAX_SIZE32 then
    raise EInvalidOperationError.Create('zip writer: entry size exceeds ZIP32 limit (4 GiB)');
  { 本地头 30 字节 + 名长 + 数据长必须仍落在 4 GiB 内，保证 central dir 偏移不溢出 }
  if (Int64(FOut.Length) + 30 + Length(AName) + Length(AData)) > Int64(C_ZIP_MAX_SIZE32) then
    raise EInvalidOperationError.Create('zip writer: archive size exceeds ZIP32 limit (4 GiB)');

  LSize := LongWord(Length(AData));
  LCrc := Crc32OfBytes(AData);
  DosDateTimeFromUnix(AModTimeUnixSec, LDosDate, LDosTime);

  LMeta.FName := AName;
  LMeta.FCrc := LCrc;
  LMeta.FSize := LSize;
  LMeta.FDosTime := LDosTime;
  LMeta.FDosDate := LDosDate;
  LMeta.FLocalOffset := LongWord(FOut.Length);
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := LMeta;

  FOut.AppendUInt32LE(C_ZIP_LOCAL_SIG);
  FOut.AppendUInt16LE(C_ZIP_VERSION_DEFAULT);
  FOut.AppendUInt16LE(C_ZIP_FLAG_UTF8);
  FOut.AppendUInt16LE(C_ZIP_METHOD_STORE);
  FOut.AppendUInt16LE(LDosTime);
  FOut.AppendUInt16LE(LDosDate);
  FOut.AppendUInt32LE(LCrc);
  FOut.AppendUInt32LE(LSize);
  FOut.AppendUInt32LE(LSize);
  FOut.AppendUInt16LE(Word(Length(AName)));
  FOut.AppendUInt16LE(0);
  if Length(AName) > 0 then
    FOut.AppendBytes(PByte(Pointer(AName)), Length(AName));
  if Length(AData) > 0 then
    FOut.AppendBytes(PByte(AData), LSize);
end;

procedure TZipWriter.AddEntry(const AName: string; const AData: TBytes);
begin
  { DOS 纪元下限：确定性输出（同输入同字节），见门面注释 }
  AddEntryInternal(AName, AData, DosMinUnixSec);
end;

procedure TZipWriter.AddEntryWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64);
begin
  AddEntryInternal(AName, AData, AModTimeUnixSec);
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
    FOut.AppendUInt16LE(C_ZIP_METHOD_STORE);
    FOut.AppendUInt16LE(LE.FDosTime);
    FOut.AppendUInt16LE(LE.FDosDate);
    FOut.AppendUInt32LE(LE.FCrc);
    FOut.AppendUInt32LE(LE.FSize);
    FOut.AppendUInt32LE(LE.FSize);
    FOut.AppendUInt16LE(Word(Length(LE.FName)));
    FOut.AppendUInt16LE(0);  { extra len }
    FOut.AppendUInt16LE(0);  { comment len }
    FOut.AppendUInt16LE(0);  { disk number start }
    FOut.AppendUInt16LE(0);  { internal attrs }
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
