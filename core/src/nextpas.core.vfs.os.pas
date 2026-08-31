unit nextpas.core.vfs.os;

{** @desc os 后端：真实文件系统上的只读 IVfs 视图。本单元是 vfs 模块唯一的
  L2→L2 seam（依赖 nextpas.core.fs），registry 记录在案。
  错误映射两段式：操作前 Stat 探测产出精确 EVfs* 类；残余未预期 fs 错误
  统一包 EVfsError(Op/Path) 并保留原始消息，不吞细节（INV-V4/V5）。
  INV-V10：大小写敏感性跟随平台，实例上可查询。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

{ ARoot 必须是已存在的目录；不存在抛 EVfsNotFound，非目录抛 EVfsNotADirectory。
  ARoot 使用平台原生路径（相对路径按进程 CWD 解析）。 }
function CreateOsVfs(const ARoot: string): IVfs;

implementation

{ 根目录子项名 = 子项名本身；其余 = 目录虚拟路径 + '/' + 名 }
function FullVirtualName(const ADirPath, AName: string): string;
begin
  if VfsIsRoot(ADirPath) then
    Result := AName
  else
    Result := ADirPath + '/' + AName;
end;

type
  { 只读流适配器：委托 IFile，同时暴露 IReaderAt（INV-V12 三后端一致） }
  TOsStream = class(TInterfacedObject, IStream, IReaderAt)
  private
    FFile: IFile;
    FOpen: Boolean;
    FPath: string;
    procedure CheckOpen;
  public
    constructor Create(AFile: IFile; const APath: string);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function ReadAt(var ABuf; const ACount: SizeUInt;
      const AOffset: Int64): SizeUInt;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

  TOsVfs = class(TInterfacedObject, IVfs)
  private
    FRoot: string;
    function FullPath(const APath: string): string;
    function MapInfo(const AName: string; const AFi: TFileInfo): TEntryInfo;
  public
    constructor Create(const ARoot: string);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
  end;

function CreateOsVfs(const ARoot: string): IVfs;
begin
  Result := TOsVfs.Create(ARoot);
end;

{ ── TOsStream ── }

constructor TOsStream.Create(AFile: IFile; const APath: string);
begin
  inherited Create;
  FFile := AFile;
  FOpen := True;
  FPath := APath;
end;

destructor TOsStream.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TOsStream.CheckOpen;
begin
  if not FOpen then
    raise EVfsClosed.CreateCtx('read', FPath, 'stream already closed');
end;

function TOsStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  CheckOpen;
  Result := FFile.Read(ABuf, ACount);
end;

function TOsStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;  { 只读流：写入一律抛错，返回值仅为满足签名 }
  raise EVfsError.CreateCtx('write', FPath, 'stream is read-only');
end;

function TOsStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  CheckOpen;
  Result := FFile.Seek(AOffset, AOrigin);
end;

procedure TOsStream.Close;
begin
  if FOpen then
  begin
    FOpen := False;
    FFile.Close;
  end;
end;

function TOsStream.GetSize: Int64;
begin
  CheckOpen;
  Result := FFile.Size;
end;

function TOsStream.GetPosition: Int64;
begin
  CheckOpen;
  Result := FFile.Position;
end;

procedure TOsStream.SetPosition(const AValue: Int64);
var
  Clamped: Int64;
begin
  CheckOpen;
  if AValue < 0 then
    Clamped := 0
  else if AValue > FFile.Size then
    Clamped := FFile.Size
  else
    Clamped := AValue;
  FFile.Position := Clamped;
end;

function TOsStream.ReadAt(var ABuf; const ACount: SizeUInt;
  const AOffset: Int64): SizeUInt;
begin
  CheckOpen;
  Result := FFile.ReadAt(ABuf, ACount, AOffset);
end;

{ ── TOsVfs ── }

constructor TOsVfs.Create(const ARoot: string);
var
  FI: TFileInfo;
begin
  inherited Create;
  try
    FI := nextpas.core.fs.Stat(ARoot);
  except
    on E: Exception do
      raise EVfsNotFound.CreateCtx('mount', ARoot,
        'os root not accessible: ' + E.Message);
  end;
  if not FI.IsDir then
    raise EVfsNotADirectory.CreateCtx('mount', ARoot, 'os root is not a directory');
  FRoot := nextpas.core.fs.PathTrimSep(ARoot);
end;

function TOsVfs.FullPath(const APath: string): string;
begin
  if VfsIsRoot(APath) then
    Result := FRoot
  else
    Result := FRoot + '/' + APath;
end;

function TOsVfs.MapInfo(const AName: string; const AFi: TFileInfo): TEntryInfo;
begin
  Result.Name := AName;
  Result.Size := AFi.Size;
  { fs 报告 Unix 纳秒；TEntryInfo 契约为秒（与 TEntryInfo 注释一致） }
  Result.ModTime := AFi.ModTime div 1000000000;
  Result.IsDir := AFi.IsDir;
end;

function TOsVfs.Exists(const APath: string): Boolean;
begin
  if not VfsValidPath(APath, True) then
    Exit(False);
  try
    nextpas.core.fs.Stat(FullPath(APath));
    Result := True;
  except
    Result := False;
  end;
end;

function TOsVfs.Stat(const APath: string): TStatInfo;
var
  FI: TFileInfo;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  try
    FI := nextpas.core.fs.Stat(FullPath(APath));
  except
    on E: ENotFoundError do
      raise EVfsNotFound.CreateCtx('stat', APath, 'not found: ' + E.Message);
    on E: EVfsError do raise;
    on E: Exception do
      raise EVfsError.CreateCtx('stat', APath, E.Message);
  end;
  Result.Info := MapInfo(APath, FI);
  Result.ContentHash := 0;   { os 后端不提供内容哈希 }
end;

function TOsVfs.List(const ADirPath: string): TEntryArray;
var
  Entries: TDirEntryArray;
  I: SizeUInt;
  OutN: SizeUInt;
  FI: TFileInfo;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');

  { 两段式：先探测目录本身，缺失/非目录给精确错类 }
  try
    FI := nextpas.core.fs.Stat(FullPath(ADirPath));
  except
    on E: ENotFoundError do
      raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found: ' + E.Message);
    on E: EVfsError do raise;
    on E: Exception do
      raise EVfsError.CreateCtx('list', ADirPath, E.Message);
  end;
  if not FI.IsDir then
    raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is not a directory');

  try
    Entries := nextpas.core.fs.ReadDir(FullPath(ADirPath));
  except
    on E: Exception do
      raise EVfsError.CreateCtx('list', ADirPath,
        'readdir failed: ' + E.Message);
  end;

  Result := nil;
  SetLength(Result, SizeUInt(Length(Entries)));
  OutN := 0;
  for I := 0 to SizeUInt(Length(Entries)) - 1 do
  begin
    { symlink 跳过：与 dirsource/memtree 模型一致——视图里没有链接条目 }
    if Entries[I].FileType = ftSymlink then
      Continue;
    try
      FI := nextpas.core.fs.Stat(FullPath(ADirPath) + '/' + Entries[I].Name);
    except
      on E: Exception do
        raise EVfsError.CreateCtx('list', ADirPath,
          'stat failed for child ' + Entries[I].Name + ': ' + E.Message);
    end;
    Result[OutN] := MapInfo(FullVirtualName(ADirPath, Entries[I].Name), FI);
    Inc(OutN);
  end;
  SetLength(Result, OutN);
  VfsSortEntries(Result);
end;

function TOsVfs.OpenRead(const APath: string): IStream;
var
  SI: TStatInfo;
  LFile: IFile;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  { 先 Stat 分类，保证错误类精确（INV-V5） }
  SI := Stat(APath);
  if SI.Info.IsDir then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  try
    LFile := nextpas.core.fs.Open(FullPath(APath), [fmRead]);
  except
    on E: Exception do
      raise EVfsError.CreateCtx('open', APath, 'open failed: ' + E.Message);
  end;
  Result := TOsStream.Create(LFile, APath);
end;

function TOsVfs.CaseSensitive: Boolean;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := False;
  {$ELSE}
  Result := True;
  {$ENDIF}
end;

end.
