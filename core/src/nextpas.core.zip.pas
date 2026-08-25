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
  nextpas.core.zip.base,
  nextpas.core.zip.writer,
  nextpas.core.zip.reader,
  nextpas.core.zip.fs;

type
  TZipMethod = nextpas.core.zip.base.TZipMethod;
  TZipEntryInfo = nextpas.core.zip.base.TZipEntryInfo;
  TZipWriteOptions = nextpas.core.zip.writer.TZipWriteOptions;
  TZipAddOptions = nextpas.core.zip.writer.TZipAddOptions;
  TZipReadOptions = nextpas.core.zip.reader.TZipReadOptions;
  TZipExtractOptions = nextpas.core.zip.fs.TZipExtractOptions;
  IZipWriter = nextpas.core.zip.writer.IZipWriter;
  IZipReader = nextpas.core.zip.reader.IZipReader;

const
  C_ZIP_DEFAULT_MAX_OUTPUT = nextpas.core.zip.reader.C_ZIP_DEFAULT_MAX_OUTPUT;

function NewZipWriter: IZipWriter; inline;
function DefaultZipWriteOptions: TZipWriteOptions; inline;
function NewZipWriterWithOptions(const AOptions: TZipWriteOptions): IZipWriter; inline;
function DefaultZipAddOptions: TZipAddOptions; inline;
function DefaultZipReadOptions: TZipReadOptions; inline;
function NewZipReader(const AData: TBytes): IZipReader; inline;
function NewZipReaderWithOptions(const AData: TBytes;
  const AOptions: TZipReadOptions): IZipReader; inline;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter); inline;
function ZipPackDir(const ADir: string): TBytes; inline;
function DefaultZipExtractOptions: TZipExtractOptions; inline;
procedure ZipExtractToDirWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions); inline;
procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt = 0); inline;

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

function DefaultZipReadOptions: TZipReadOptions;
begin
  Result := nextpas.core.zip.reader.DefaultZipReadOptions;
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

end.
