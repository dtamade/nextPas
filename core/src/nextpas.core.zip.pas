{**
 * nextpas.core.zip - ZIP 归档容器写器（STORE）
 *
 * 最小 ZIP 写端：只产出 method=0（store）条目的标准归档容器，覆盖
 * 「把已压缩载荷（图像等）打包分发」类需求；deflate 压缩由 compress 域负责，
 * 不在本单元重复。结构为 local file header + central directory + EOCD，
 * 任何标准解压器（unzip / python zipfile / Go archive/zip）可直接读取。
 *
 * 约束（ZIP32 上限，Zip64 后置）：条目数 ≤ 65535、单条目尺寸与归档偏移 < 4 GiB，
 * 超限显式 raise，绝不静默产出损坏归档。
 * 文件名一律按 UTF-8 写入（general purpose flag bit 11），并拒绝 zip-slip 危险形态：
 * 空名、绝对路径、盘符前缀、反斜杠、'..' 路径段。
 * 未指定时间戳的条目取 DOS 纪元下限（1980-01-01），保证同输入字节级可复现；
 * 显式时间戳越出 DOS 可表达区间时钳制到边界，不 raise。
 *}

unit nextpas.core.zip;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.builder;

type
  {** @desc ZIP 归档写器（store 条目，顺序追加，Finish 一次性终结） *}
  IZipWriter = interface
    ['{D09A5E11-3F42-4C8B-9A17-6E2C80B41F33}']
    {** 添加 store 条目；时间戳取 DOS 下限（确定性输出） *}
    procedure AddEntry(const AName: string; const AData: TBytes);
    {** 添加 store 条目，AModTimeUnixSec 为 unix 秒（越界钳制到 DOS 区间） *}
    procedure AddEntryWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64);
    {** 已添加条目数 *}
    function EntryCount: Integer;
    {** 终结并返回完整归档字节；此后 AddEntry*/AddEntryWithTime/Finish 均 raise *}
    function Finish: TBytes;
  end;

function NewZipWriter: IZipWriter;

implementation

uses
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.time.date;

const
  C_ZIP_LOCAL_SIG   = $04034B50;
  C_ZIP_CENTRAL_SIG = $02014B50;
  C_ZIP_EOCD_SIG    = $06054B50;

  C_ZIP_VERSION_NEEDED = 20;       { PKZIP 2.0 基线 }
  C_ZIP_FLAG_UTF8      = $0800;    { general purpose flag bit 11 }
  C_ZIP_METHOD_STORE   = 0;
  C_ZIP_MADE_BY_UNIX   = 3 shl 8;  { version made by：host = Unix }

  C_ZIP_MAX_ENTRIES    = 65535;
  C_ZIP_MAX_SIZE       = $FFFFFFFF; { ZIP32 无符号 32 位字段上限 }
  C_ZIP_MAX_NAME_BYTES = High(Word);

  C_DOS_MIN_YEAR = 1980;
  C_DOS_MAX_YEAR = 2107;

  { Unix mode 高 16 位：S_IFREG | 0644 }
  C_ZIP_EXTERNAL_ATTR_REGULAR = $81A4 shl 16;

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

procedure ValidateEntryName(const AName: string);
var
  LI, LSegStart: Integer;
begin
  if AName = '' then
    raise EArgumentError.Create('zip entry name must not be empty');
  if Length(AName) > C_ZIP_MAX_NAME_BYTES then
    raise EArgumentError.Create('zip entry name exceeds ' +
      IntToStr(C_ZIP_MAX_NAME_BYTES) + ' bytes');
  if AName[1] = '/' then
    raise EArgumentError.Create('zip entry name must not be absolute: ' + AName);
  if (Length(AName) >= 2) and (AName[2] = ':') and
     (UpCase(AName[1]) in ['A'..'Z']) then
    raise EArgumentError.Create('zip entry name must not carry a drive prefix: ' + AName);
  LSegStart := 1;
  for LI := 1 to Length(AName) + 1 do
  begin
    if (LI <= Length(AName)) and (AName[LI] <> '/') then
    begin
      if AName[LI] = '\' then
        raise EArgumentError.Create('zip entry name must use ''/'', not backslash: ' + AName);
      Continue;
    end;
    { 段边界：[LSegStart, LI-1]；空段（如尾随 '/'）合法 }
    if (LI - LSegStart = 2) and (AName[LSegStart] = '.') and
       (AName[LSegStart + 1] = '.') then
      raise EArgumentError.Create('zip entry name must not contain a ''..'' segment: ' + AName);
    LSegStart := LI + 1;
  end;
end;

{ unix 秒 → DOS 日期/时间字。越界钳制到 [1980-01-01, 2107-12-31 23:59:59]。 }
procedure DosDateTimeFromUnix(AUnixSec: Int64; out ADosDate, ADosTime: Word);
var
  LMinSec, LMaxSec, LRem: Int64;
  LD: TDate;
begin
  LMinSec := Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400;
  LMaxSec := Int64(TDate.Create(C_DOS_MAX_YEAR, 12, 31).ToUnixDays) * 86400 + 86399;
  if AUnixSec < LMinSec then
    AUnixSec := LMinSec
  else if AUnixSec > LMaxSec then
    AUnixSec := LMaxSec;
  LD := TDate.FromUnixDays(Integer(AUnixSec div 86400));
  LRem := AUnixSec mod 86400;
  ADosDate := Word(((LD.GetYear - C_DOS_MIN_YEAR) shl 9) or
    (LD.GetMonth shl 5) or LD.GetDay);
  ADosTime := Word(((LRem div 3600) shl 11) or
    (((LRem mod 3600) div 60) shl 5) or ((LRem mod 60) div 2));
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
  ValidateEntryName(AName);
  if Length(FEntries) >= C_ZIP_MAX_ENTRIES then
    raise EInvalidOperationError.Create('zip writer: entry count exceeds ZIP32 limit (' +
      IntToStr(C_ZIP_MAX_ENTRIES) + ')');
  if SizeUInt(Length(AData)) > C_ZIP_MAX_SIZE then
    raise EInvalidOperationError.Create('zip writer: entry size exceeds ZIP32 limit (4 GiB)');
  { 本地头 30 字节 + 名长 + 数据长必须仍落在 4 GiB 内，保证 central dir 偏移不溢出 }
  if (Int64(FOut.Length) + 30 + Length(AName) + Length(AData)) > Int64(C_ZIP_MAX_SIZE) then
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
  FOut.AppendUInt16LE(C_ZIP_VERSION_NEEDED);
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
  { DOS 纪元下限：确定性输出（同输入同字节），见单元头注释 }
  AddEntryInternal(AName, AData,
    Int64(TDate.Create(C_DOS_MIN_YEAR, 1, 1).ToUnixDays) * 86400);
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
    FOut.AppendUInt16LE(C_ZIP_MADE_BY_UNIX or C_ZIP_VERSION_NEEDED);
    FOut.AppendUInt16LE(C_ZIP_VERSION_NEEDED);
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
