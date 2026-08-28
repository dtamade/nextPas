unit nextpas.core.zip.builder;
{**
 * @desc ZIP Fluent Builder：对 `IZipWriter` 的零成本链式门面，
 *       以高级感的 `ZipBuilder.Add(...).AddDeflate(...).Finish` 形态
 *       覆盖常见打包路径。委托 `IZipWriter` 实现，字节形态与
 *       直接写器全等，`Reserve` 用于 200+ 条目预分配以避免几何扩容。
 *
 * 约束：链式方法一律返回 `Self`；流式条目经 `AddEntryStream`
 *       直通写器（语义与 `IZipWriter.AddEntryStream` 一致，含
 *       DataDescriptor 直写与 fail-closed）；`Finish` 后再次添加
 *       或再次 `Finish` 遵循底层写器语义（`EInvalidOperationError`）。
 *       `StreamTo` 绑定后 `Finish` 需经 `FinishTo` 完成。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip.base,
  nextpas.core.zip.writer;

type
  {** @desc ZIP 链式构造器（Fluent Builder，薄委托层） *}
  IZipBuilder = interface
    ['{7B4E9A11-8D2F-4C3A-A1F6-9C2D5E8B0A3F}']
    function Add(const AName: string; const AData: TBytes): IZipBuilder;
    function AddDeflate(const AName: string; const AData: TBytes): IZipBuilder;
    function AddWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes;
      const AOptions: TZipAddOptions): IZipBuilder;
    function AddDirectory(const AName: string): IZipBuilder;
    function AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddEntryStream(const AName: string;
      const AOptions: TZipAddOptions): ICompressWriter;
    function Reserve(ACapacity: Integer): IZipBuilder;
    function StreamTo(const ASink: IWriter): IZipBuilder;
    function Finish: TBytes;
    function FinishTo(const ASink: IWriter): UInt64;
    function EntryCount: Integer;
  end;

function ZipBuilder: IZipBuilder; inline;
function ZipBuilderForceZip64: IZipBuilder; inline;
function NewZipBuilder: IZipBuilder; inline;
function NewZipBuilderWithOptions(const AOptions: TZipWriteOptions): IZipBuilder;

implementation

type
  TZipBuilder = class(TInterfacedObject, IZipBuilder)
  private
    FWriter: IZipWriter;
  public
    constructor Create(const AWriter: IZipWriter);
    function Add(const AName: string; const AData: TBytes): IZipBuilder;
    function AddDeflate(const AName: string; const AData: TBytes): IZipBuilder;
    function AddWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddDeflateWithTime(const AName: string; const AData: TBytes;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes;
      const AOptions: TZipAddOptions): IZipBuilder;
    function AddDirectory(const AName: string): IZipBuilder;
    function AddDirectoryWithTime(const AName: string;
      const AModTimeUnixSec: Int64): IZipBuilder;
    function AddEntryStream(const AName: string;
      const AOptions: TZipAddOptions): ICompressWriter;
    function Reserve(ACapacity: Integer): IZipBuilder;
    function StreamTo(const ASink: IWriter): IZipBuilder;
    function Finish: TBytes;
    function FinishTo(const ASink: IWriter): UInt64;
    function EntryCount: Integer;
  end;

constructor TZipBuilder.Create(const AWriter: IZipWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

function TZipBuilder.Add(const AName: string; const AData: TBytes): IZipBuilder;
begin
  FWriter.AddEntry(AName, AData);
  Result := Self;
end;

function TZipBuilder.AddDeflate(const AName: string; const AData: TBytes): IZipBuilder;
begin
  FWriter.AddEntryDeflate(AName, AData);
  Result := Self;
end;

function TZipBuilder.AddWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64): IZipBuilder;
begin
  FWriter.AddEntryWithTime(AName, AData, AModTimeUnixSec);
  Result := Self;
end;

function TZipBuilder.AddDeflateWithTime(const AName: string; const AData: TBytes;
  const AModTimeUnixSec: Int64): IZipBuilder;
begin
  FWriter.AddEntryDeflateWithTime(AName, AData, AModTimeUnixSec);
  Result := Self;
end;

function TZipBuilder.AddWithOptions(const AName: string; const AData: TBytes;
  const AOptions: TZipAddOptions): IZipBuilder;
begin
  FWriter.AddEntryWithOptions(AName, AData, AOptions);
  Result := Self;
end;

function TZipBuilder.AddDirectory(const AName: string): IZipBuilder;
begin
  FWriter.AddDirectory(AName);
  Result := Self;
end;

function TZipBuilder.AddDirectoryWithTime(const AName: string;
  const AModTimeUnixSec: Int64): IZipBuilder;
begin
  FWriter.AddDirectoryWithTime(AName, AModTimeUnixSec);
  Result := Self;
end;

function TZipBuilder.AddEntryStream(const AName: string;
  const AOptions: TZipAddOptions): ICompressWriter;
begin
  Result := FWriter.AddEntryStream(AName, AOptions);
end;

function TZipBuilder.Reserve(ACapacity: Integer): IZipBuilder;
begin
  FWriter.Reserve(ACapacity);
  Result := Self;
end;

function TZipBuilder.StreamTo(const ASink: IWriter): IZipBuilder;
begin
  FWriter.StreamOutputTo(ASink);
  Result := Self;
end;

function TZipBuilder.Finish: TBytes;
begin
  Result := FWriter.Finish;
end;

function TZipBuilder.FinishTo(const ASink: IWriter): UInt64;
begin
  Result := FWriter.FinishTo(ASink);
end;

function TZipBuilder.EntryCount: Integer;
begin
  Result := FWriter.EntryCount;
end;

function NewZipBuilderWithOptions(const AOptions: TZipWriteOptions): IZipBuilder;
begin
  Result := TZipBuilder.Create(NewZipWriterWithOptions(AOptions));
end;

function NewZipBuilder: IZipBuilder;
begin
  Result := NewZipBuilderWithOptions(DefaultZipWriteOptions);
end;

function ZipBuilder: IZipBuilder;
begin
  Result := NewZipBuilder;
end;

function ZipBuilderForceZip64: IZipBuilder;
var
  LOpts: TZipWriteOptions;
begin
  LOpts.ForceZip64 := True;
  Result := NewZipBuilderWithOptions(LOpts);
end;

end.
