unit nextpas.core.io.linewriter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.io.intf,
  nextpas.core.errors;

type
  ILineWriter = interface(IWriter)
    ['{C3D4E5F6-A7B8-9012-CDEF-AB3456789012}']
    procedure WriteLine(const ALine: string);
    procedure Flush;
  end;

function CreateLineWriter(const AWriter: IWriter;
  const ALineSep: string = #10): ILineWriter;

{** 创建控制台行写入器（输出到 stdout） }
function CreateConsoleWriter: ILineWriter;

{** 创建标准错误行写入器（输出到 stderr） }
function CreateStderrWriter: ILineWriter;

procedure IoWriteLine(const AWriter: IWriter; const ALine: string);
procedure IoWriteLines(const AWriter: IWriter; const ALines: TStringArray);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.io.util;

type
  TLineWriter = class(TInterfacedObject, IWriter, ILineWriter)
  private
    FInner: IWriter;
    FLineSep: string;
  public
    constructor Create(const AInner: IWriter; const ALineSep: string);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure WriteLine(const ALine: string);
    procedure Flush;
  end;

  {** 控制台行写入器 — 直接输出到 stdout }
  TConsoleWriter = class(TInterfacedObject, ILineWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure WriteLine(const ALine: string);
    procedure Flush;
  end;

  {** 标准错误行写入器 — 直接输出到 stderr }
  TStderrWriter = class(TInterfacedObject, ILineWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure WriteLine(const ALine: string);
    procedure Flush;
  end;

constructor TLineWriter.Create(const AInner: IWriter; const ALineSep: string);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentError.Create('TLineWriter: inner writer is nil');
  FInner := AInner;
  FLineSep := ALineSep;
end;

function TLineWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

procedure TLineWriter.WriteLine(const ALine: string);
begin
  nextpas.core.io.util.IoWriteString(FInner, ALine);
  nextpas.core.io.util.IoWriteString(FInner, FLineSep);
end;

procedure TLineWriter.Flush;
var
  LFlusher: IFlusher;
begin
  if Supports(FInner, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function CreateLineWriter(const AWriter: IWriter;
  const ALineSep: string): ILineWriter;
begin
  Result := TLineWriter.Create(AWriter, ALineSep);
end;

{ ===== TConsoleWriter ===== }

function TConsoleWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  { Write 是二进制接口，控制台场景下不实现 }
  Result := 0;
end;

procedure TConsoleWriter.WriteLine(const ALine: string);
begin
  WriteLn(ALine);
end;

procedure TConsoleWriter.Flush;
begin
  { stdout 默认行缓冲，无需额外 flush }
end;

{ ===== TStderrWriter ===== }

function TStderrWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

procedure TStderrWriter.WriteLine(const ALine: string);
begin
  WriteLn(StdErr, ALine);
end;

procedure TStderrWriter.Flush;
begin
end;

{ ===== Factory functions ===== }

function CreateConsoleWriter: ILineWriter;
begin
  Result := TConsoleWriter.Create;
end;

function CreateStderrWriter: ILineWriter;
begin
  Result := TStderrWriter.Create;
end;

procedure IoWriteLine(const AWriter: IWriter; const ALine: string);
begin
  nextpas.core.io.util.IoWriteString(AWriter, ALine);
  nextpas.core.io.util.IoWriteString(AWriter, #10);
end;

procedure IoWriteLines(const AWriter: IWriter; const ALines: TStringArray);
var
  LI: Int32;
begin
  for LI := 0 to Length(ALines) - 1 do
    IoWriteLine(AWriter, ALines[LI]);
end;

end.
