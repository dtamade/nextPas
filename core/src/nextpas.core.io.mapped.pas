unit nextpas.core.io.mapped;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.io.intf;

type
  IMappedFile = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-BC4567890123}']
    function Data: PByte;
    function Size: Int64;
    function AsView: TStringView;
  end;

  IMappedLines = interface
    ['{E5F6A7B8-C9D0-1234-EFAB-CD5678901234}']
    function Count: Int32;
    function Line(AIndex: Int32): TStringView;
    function IndexOf(const APattern: string): Int32;
    function Contains(const APattern: string): Boolean;
  end;

function MmapOpen(const APath: string): IMappedFile;
function MmapLines(const APath: string): IMappedLines;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.mmap;

type
  TMappedFileImpl = class(TInterfacedObject, IMappedFile)
  private
    FMap: TPlatformMappedFile;
    FValid: Boolean;
  public
    constructor Create(const APath: string);
    destructor Destroy; override;
    function Data: PByte;
    function Size: Int64;
    function AsView: TStringView;
  end;

  TMappedLinesImpl = class(TInterfacedObject, IMappedLines)
  private
    FFile: IMappedFile;
    FLineStarts: array of UInt32;
    FLineLens: array of UInt32;
    FCount: Int32;
    procedure BuildIndex;
  public
    constructor Create(const APath: string);
    function Count: Int32;
    function Line(AIndex: Int32): TStringView;
    function IndexOf(const APattern: string): Int32;
    function Contains(const APattern: string): Boolean;
  end;

{ TMappedFileImpl }

constructor TMappedFileImpl.Create(const APath: string);
var
  LRet: Int32;
begin
  inherited Create;
  FValid := False;
  LRet := platform_mmap_file(PAnsiChar(APath), FMap);
  if LRet <> 0 then
  begin
    // Empty file or error — set size 0, no mapping
    FMap.Addr := nil;
    FMap.Size := 0;
    Exit;
  end;
  FValid := True;
end;

destructor TMappedFileImpl.Destroy;
begin
  if FValid then
    platform_mmap_close(FMap);
  inherited;
end;

function TMappedFileImpl.Data: PByte;
begin
  if FValid then
    Result := PByte(FMap.Addr)
  else
    Result := nil;
end;

function TMappedFileImpl.Size: Int64;
begin
  if FValid then
    Result := Int64(FMap.Size)
  else
    Result := 0;
end;

function TMappedFileImpl.AsView: TStringView;
begin
  if FValid and (FMap.Addr <> nil) then
    Result := TStringView.Create(PAnsiChar(FMap.Addr), FMap.Size)
  else
    Result := TStringView.Empty;
end;

{ TMappedLinesImpl }

constructor TMappedLinesImpl.Create(const APath: string);
begin
  inherited Create;
  FFile := MmapOpen(APath);
  FCount := 0;
  BuildIndex;
end;

procedure TMappedLinesImpl.BuildIndex;
var
  LP: PByte;
  LSize: Int64;
  LI: Int64;
  LStart: UInt32;
  LCap: Int32;
begin
  LP := FFile.Data;
  LSize := FFile.Size;
  if (LP = nil) or (LSize = 0) then Exit;

  LCap := Int32(LSize div 40) + 16;
  SetLength(FLineStarts, LCap);
  SetLength(FLineLens, LCap);

  LStart := 0;
  FCount := 0;
  for LI := 0 to LSize - 1 do
  begin
    if LP[LI] = 10 then
    begin
      if FCount >= LCap then
      begin
        LCap := LCap * 2;
        SetLength(FLineStarts, LCap);
        SetLength(FLineLens, LCap);
      end;
      FLineStarts[FCount] := LStart;
      if (LI > LStart) and (LP[LI - 1] = 13) then
        FLineLens[FCount] := UInt32(LI) - LStart - 1
      else
        FLineLens[FCount] := UInt32(LI) - LStart;
      Inc(FCount);
      LStart := UInt32(LI) + 1;
    end;
  end;
  if LStart < UInt32(LSize) then
  begin
    if FCount >= LCap then
    begin
      Inc(LCap);
      SetLength(FLineStarts, LCap);
      SetLength(FLineLens, LCap);
    end;
    FLineStarts[FCount] := LStart;
    FLineLens[FCount] := UInt32(LSize) - LStart;
    Inc(FCount);
  end;
end;

function TMappedLinesImpl.Count: Int32;
begin
  Result := FCount;
end;

function TMappedLinesImpl.Line(AIndex: Int32): TStringView;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Result := TStringView.Empty
  else
    Result := TStringView.Create(
      PAnsiChar(FFile.Data) + FLineStarts[AIndex],
      FLineLens[AIndex]);
end;

function TMappedLinesImpl.IndexOf(const APattern: string): Int32;
var
  LI: Int32;
  LView: TStringView;
  LPat: TStringView;
begin
  LPat := TStringView.FromStr(APattern);
  for LI := 0 to FCount - 1 do
  begin
    LView := Line(LI);
    if LView.IndexOfStr(LPat) >= 0 then
    begin
      Result := LI;
      Exit;
    end;
  end;
  Result := -1;
end;

function TMappedLinesImpl.Contains(const APattern: string): Boolean;
begin
  Result := IndexOf(APattern) >= 0;
end;

{ Factory }

function MmapOpen(const APath: string): IMappedFile;
begin
  Result := TMappedFileImpl.Create(APath);
end;

function MmapLines(const APath: string): IMappedLines;
begin
  Result := TMappedLinesImpl.Create(APath);
end;

end.
