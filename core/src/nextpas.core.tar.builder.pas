unit nextpas.core.tar.builder;
{**
 * @desc Tar 链式构造器：ZipBuilder 手感的薄门面，委托 TTarWriter。
 * 仅做流畅 API 封装，不含序列化逻辑，保证 bytes 级一致。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.tar.base,
  nextpas.core.tar.writer;

type
  ITarBuilder = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111111111}']
    function Add(const AName: string; const AData: TBytes): ITarBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder;
    function AddDirectory(const AName: string): ITarBuilder;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder;
    function Finish: TBytes;
  end;

function TarBuilder: ITarBuilder;
function NewTarBuilder: ITarBuilder; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.io.memory;

type
  TTarBuilder = class(TInterfacedObject, ITarBuilder)
  private
    FStream: IStream;
    FWriter: TTarWriter;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName: string; const AData: TBytes): ITarBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder;
    function AddDirectory(const AName: string): ITarBuilder;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder;
    function Finish: TBytes;
  end;

constructor TTarBuilder.Create;
begin
  inherited Create;
  FStream := CreateBytesStream;
  FWriter := TTarWriter.Create(FStream as IWriter);
end;

destructor TTarBuilder.Destroy;
begin
  FWriter.Free;
  inherited Destroy;
end;

function TTarBuilder.Add(const AName: string; const AData: TBytes): ITarBuilder;
begin
  FWriter.AddFile(AName, AData);
  Result := Self;
end;

function TTarBuilder.AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder;
begin
  FWriter.AddEntryWithOptions(AName, AData, AOpts);
  Result := Self;
end;

function TTarBuilder.AddDirectory(const AName: string): ITarBuilder;
begin
  FWriter.AddDir(AName);
  Result := Self;
end;

function TTarBuilder.AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder;
var
  H: TTarHeader;
begin
  H := Default(TTarHeader);
  H.Name := AName;
  H.Kind := tekDirectory;
  H.Mode := AOpts.Mode;
  if H.Mode = 0 then
    H.Mode := $1ED;
  H.MTimeUnix := AOpts.MTimeUnix;
  H.UName := AOpts.UName;
  H.GName := AOpts.GName;
  FWriter.AddEntry(H, nil);
  Result := Self;
end;

function TTarBuilder.AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder;
begin
  FWriter.AddEntry(AHdr, AData);
  Result := Self;
end;

function TTarBuilder.Finish: TBytes;
begin
  FWriter.Finish;
  SetLength(Result, FStream.Size);
  if Length(Result) > 0 then
  begin
    FStream.Seek(0, soBeginning);
    if FStream.Read(Result[0], Length(Result)) <> Length(Result) then
      raise EIOError.Create('tar builder: short snapshot');
  end;
end;

function TarBuilder: ITarBuilder;
begin
  Result := TTarBuilder.Create;
end;

function NewTarBuilder: ITarBuilder;
begin
  Result := TarBuilder;
end;

end.
