unit nextpas.core.zip;
{**
 * @desc ZIP 归档容器门面：写器（store/deflate 条目）、读器（解析/提取/校验）。
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
  nextpas.core.zip.writer;

type
  TZipMethod = nextpas.core.zip.base.TZipMethod;
  TZipEntryInfo = nextpas.core.zip.base.TZipEntryInfo;
  IZipWriter = nextpas.core.zip.writer.IZipWriter;

function NewZipWriter: IZipWriter; inline;

implementation

function NewZipWriter: IZipWriter;
begin
  Result := nextpas.core.zip.writer.NewZipWriter;
end;

end.
