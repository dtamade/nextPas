unit nextpas.core.io.linewriter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.io.intf;

type
  ILineWriter = interface(IWriter)
    ['{C3D4E5F6-A7B8-9012-CDEF-AB3456789012}']
    procedure WriteLine(const ALine: string);
    procedure Flush;
  end;

function CreateLineWriter(const AWriter: IWriter;
  const ALineSep: string = #10): ILineWriter;

procedure IoWriteLine(const AWriter: IWriter; const ALine: string);
procedure IoWriteLines(const AWriter: IWriter; const ALines: TStringArray);

implementation

uses
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

constructor TLineWriter.Create(const AInner: IWriter; const ALineSep: string);
begin
  inherited Create;
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
begin
  // If inner supports flush (IFlusher), call it
  // For now, no-op — buffered writer handles this
end;

function CreateLineWriter(const AWriter: IWriter;
  const ALineSep: string): ILineWriter;
begin
  Result := TLineWriter.Create(AWriter, ALineSep);
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
