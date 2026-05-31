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
  if Length(ALine) > 0 then
    FInner.Write(ALine[1], Length(ALine));
  if Length(FLineSep) > 0 then
    FInner.Write(FLineSep[1], Length(FLineSep));
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
const
  LF: AnsiChar = #10;
begin
  if Length(ALine) > 0 then
    AWriter.Write(ALine[1], Length(ALine));
  AWriter.Write(LF, 1);
end;

procedure IoWriteLines(const AWriter: IWriter; const ALines: TStringArray);
var
  LI: Int32;
begin
  for LI := 0 to Length(ALines) - 1 do
    IoWriteLine(AWriter, ALines[LI]);
end;

end.
