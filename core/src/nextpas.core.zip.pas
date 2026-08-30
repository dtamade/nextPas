unit nextpas.core.zip;
{**
 * @desc ZIP 归档容器门面：写器（store/deflate 条目、unix 权限位保留）、
 *       读器（解析/提取/校验、外部属性与符号链接判定）、fs 便捷层
 *       （目录打包、带权限/mtime 还原的解包）。
 *       结构为 local file header + central directory + EOCD，任何标准解压器
 *       （unzip / python zipfile / Go archive/zip）可直接读写。
 *
 * 约束：条目名一律 UTF-8（general purpose flag bit 11），拒绝 zip-slip 危险形态
 * （空名、绝对路径、盘符前缀、反斜杠、'..' 路径段）；未指定时间戳取 DOS 纪元
 * 下限保证同输入字节级可复现。超 ZIP32 宽度的尺寸/条目数自动启用 Zip64 结构。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip.base,
  nextpas.core.zip.writer,
  nextpas.core.zip.builder,
  nextpas.core.zip.reader,
  nextpas.core.zip.sequential,
  nextpas.core.zip.fs;

type
  TZipMethod = nextpas.core.zip.base.TZipMethod;
  TZipEntryInfo = nextpas.core.zip.base.TZipEntryInfo;
  TZipWriteOptions = nextpas.core.zip.writer.TZipWriteOptions;
  TZipAddOptions = nextpas.core.zip.writer.TZipAddOptions;
  TZipReadOptions = nextpas.core.zip.base.TZipReadOptions;
  TZipExtractOptions = nextpas.core.zip.fs.TZipExtractOptions;
  IZipWriter = nextpas.core.zip.writer.IZipWriter;
  IZipBuilder = nextpas.core.zip.builder.IZipBuilder;
  IZipReader = nextpas.core.zip.reader.IZipReader;
  ISequentialZipReader = nextpas.core.zip.sequential.ISequentialZipReader;
  { 流式条目读写端：写端经 IZipWriter.AddEntryStream 获取（推式），
    读端经 IZipReader.OpenEntry* 获取（拉式），Close/EOF 语义见各接口 }
  ICompressWriter = nextpas.core.compress.intf.ICompressWriter;
  IDecompressReader = nextpas.core.compress.intf.IDecompressReader;

const
  C_ZIP_DEFAULT_MAX_OUTPUT = nextpas.core.zip.base.C_ZIP_DEFAULT_MAX_OUTPUT;
  C_ZIP_DEFAULT_MAX_DESCRIPTOR = nextpas.core.zip.base.C_ZIP_DEFAULT_MAX_DESCRIPTOR;

function NewZipWriter: IZipWriter; inline;
function DefaultZipWriteOptions: TZipWriteOptions; inline;
function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter; inline;
function DefaultZipAddOptions: TZipAddOptions; inline;
function DefaultZipReadOptions: TZipReadOptions; inline;
function ZipUnixModeOf(const AEntry: TZipEntryInfo): Word; inline;
function ZipRegularMode(APermissionBits: Word): Word; inline;
function ZipDirectoryMode(APermissionBits: Word): Word; inline;

function NewZipReader(const AData: TBytes): IZipReader; inline;
function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader; inline;
function NewZipReaderFrom(const ASource: IStream): IZipReader; inline;
function NewZipReaderFromWithOptions(const ASource: IStream;
  const AOptions: TZipReadOptions): IZipReader; inline;
function NewZipSequentialReader(const ASource: IReader): ISequentialZipReader; inline;
function NewZipSequentialReaderWithOptions(const ASource: IReader;
  const AOptions: TZipReadOptions): ISequentialZipReader; inline;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter); inline;
function ZipPackDir(const ADir: string): TBytes; inline;
function DefaultZipExtractOptions: TZipExtractOptions; inline;
procedure ZipExtractToDirWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions); inline;
procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt = 0); inline;

function ZipBuilder: IZipBuilder; inline;
function ZipBuilderForceZip64: IZipBuilder; inline;
function NewZipBuilder: IZipBuilder; inline;
function NewZipBuilderWithOptions(const AOptions: TZipWriteOptions): IZipBuilder; inline;

implementation

function NewZipWriter: IZipWriter;
begin
  Result := nextpas.core.zip.writer.NewZipWriter;
end;

function DefaultZipWriteOptions: TZipWriteOptions;
begin
  Result := nextpas.core.zip.writer.DefaultZipWriteOptions;
end;

function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter;
begin
  Result := nextpas.core.zip.writer.NewZipWriterWithOptions(AOptions);
end;

function DefaultZipAddOptions: TZipAddOptions;
begin
  Result := nextpas.core.zip.writer.DefaultZipAddOptions;
end;

function ZipUnixModeOf(const AEntry: TZipEntryInfo): Word;
begin
  Result := nextpas.core.zip.base.ZipUnixModeOf(AEntry);
end;

function ZipRegularMode(APermissionBits: Word): Word;
begin
  Result := nextpas.core.zip.base.ZipRegularMode(APermissionBits);
end;

function ZipDirectoryMode(APermissionBits: Word): Word;
begin
  Result := nextpas.core.zip.base.ZipDirectoryMode(APermissionBits);
end;

function DefaultZipReadOptions: TZipReadOptions;
begin
  Result := nextpas.core.zip.base.DefaultZipReadOptions;
end;

function NewZipReader(const AData: TBytes): IZipReader;
begin
  Result := nextpas.core.zip.reader.NewZipReader(AData);
end;

function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader;
begin
  Result := nextpas.core.zip.reader.NewZipReaderWithOptions(AData, AOptions);
end;

function NewZipReaderFrom(const ASource: IStream): IZipReader;
begin
  Result := nextpas.core.zip.reader.NewZipReaderFrom(ASource);
end;

function NewZipReaderFromWithOptions(const ASource: IStream;
  const AOptions: TZipReadOptions): IZipReader;
begin
  Result :=
    nextpas.core.zip.reader.NewZipReaderFromWithOptions(ASource, AOptions);
end;

function NewZipSequentialReader(const ASource: IReader): ISequentialZipReader;
begin
  Result := nextpas.core.zip.sequential.NewZipSequentialReader(ASource);
end;

function NewZipSequentialReaderWithOptions(const ASource: IReader;
  const AOptions: TZipReadOptions): ISequentialZipReader;
begin
  Result := nextpas.core.zip.sequential.NewZipSequentialReaderWithOptions(
    ASource, AOptions);
end;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);
begin
  nextpas.core.zip.fs.ZipPackDirInto(ADir, AWriter);
end;

function ZipPackDir(const ADir: string): TBytes;
begin
  Result := nextpas.core.zip.fs.ZipPackDir(ADir);
end;

function DefaultZipExtractOptions: TZipExtractOptions;
begin
  Result := nextpas.core.zip.fs.DefaultZipExtractOptions;
end;

procedure ZipExtractToDirWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions);
begin
  nextpas.core.zip.fs.ZipExtractToDirWithOptions(AData, ADestDir, AOptions);
end;

procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt);
begin
  nextpas.core.zip.fs.ZipExtractToDir(AData, ADestDir, AMaxOutputSize);
end;

function ZipBuilder: IZipBuilder;
begin
  Result := nextpas.core.zip.builder.ZipBuilder;
end;

function ZipBuilderForceZip64: IZipBuilder;
begin
  Result := nextpas.core.zip.builder.ZipBuilderForceZip64;
end;

function NewZipBuilder: IZipBuilder;
begin
  Result := nextpas.core.zip.builder.NewZipBuilder;
end;

function NewZipBuilderWithOptions(const AOptions: TZipWriteOptions): IZipBuilder;
begin
  Result := nextpas.core.zip.builder.NewZipBuilderWithOptions(AOptions);
end;

end.
