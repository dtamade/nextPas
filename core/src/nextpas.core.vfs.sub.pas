unit nextpas.core.vfs.sub;

{** @desc sub 视图：任意 IVfs 的子目录重根包装（Go fs.Sub 对等物）。
  INV-V9：不改底层生命期与并发性质，纯包装零额外状态。
  错误语义：异常类与消息保持不变；Path 改写为子视图视角
  （fstest/Go 同款——调用方看到的是它传入的坐标系）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

{ ASubRoot 必须是合法虚拟路径且在 ABase 上存在且为目录；
  '.' 合法（恒等视图）。ABase 不可为 nil。 }
function CreateSubVfs(const ABase: IVfs; const ASubRoot: string): IVfs;

implementation

const
  SCSubNilBase = 'base vfs must not be nil';

type
  EVfsErrorClass = class of EVfsError;

  TSubVfs = class(TInterfacedObject, IVfs)
  private
    FBase: IVfs;
    FSubRoot: string;
    FSubPrefix: string;   { FSubRoot + '/' 缓存，identity 时为空，零重复分配 }
    FIdentity: Boolean;   { SubRoot='.' 时直通 }
    function ToBase(const APath: string): string;
    function ToSubView(const APath: string): string; inline;
    procedure ReraiseSub(E: EVfsError);
  public
    constructor Create(const ABase: IVfs; const ASubRoot: string);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
  end;

function StripTrailingSlash(const S: string): string; inline;
var
  L: Integer;
begin
  Result := S;
  if VfsIsRoot(Result) then Exit;
  L := Length(Result);
  while (L > 0) and (Result[L] = '/') do Dec(L);
  if L <> Length(Result) then SetLength(Result, L);
end;

function CreateSubVfs(const ABase: IVfs; const ASubRoot: string): IVfs;
begin
  Result := TSubVfs.Create(ABase, ASubRoot);
end;

{ ── TSubVfs ── }

constructor TSubVfs.Create(const ABase: IVfs; const ASubRoot: string);
var
  SI: TStatInfo;
begin
  inherited Create;
  if ABase = nil then
    raise EVfsError.CreateCtx('mount', ASubRoot, SCSubNilBase);
  if not VfsValidPath(ASubRoot, True) then
    raise EVfsInvalidPath.CreateCtx('mount', ASubRoot, 'invalid virtual path');
  SI := ABase.Stat(ASubRoot);   { NotFound 原样透出（路径即用户给的） }
  if not SI.Info.IsDir then
    raise EVfsNotADirectory.CreateCtx('mount', ASubRoot, 'sub root is a file');
  FBase := ABase;
  FSubRoot := StripTrailingSlash(ASubRoot);
  FIdentity := VfsIsRoot(FSubRoot);
  if FIdentity then
    FSubPrefix := ''
  else
    FSubPrefix := FSubRoot + '/';
end;

function TSubVfs.ToBase(const APath: string): string;
begin
  if FIdentity then
    Exit(APath);
  if VfsIsRoot(APath) then
    Exit(FSubRoot);
  Result := FSubPrefix + APath;
end;

function TSubVfs.ToSubView(const APath: string): string; inline;
var
  SPath, SPrefix: TByteSpan;
begin
  Result := APath;
  if FIdentity then
    Exit;
  if APath = FSubRoot then
    Exit('.');
  if Length(APath) <= Length(FSubPrefix) then
    Exit;
  // perf: zero-copy TByteSpan view single-source via bytes.ops.SpanStartsWith -> MemEqual, inline hot path, no alloc
  if Length(APath) = 0 then SPath := TByteSpan.Empty else SPath := TByteSpan.Create(PByte(@APath[1]), SizeUInt(Length(APath)));
  if Length(FSubPrefix) = 0 then SPrefix := TByteSpan.Empty else SPrefix := TByteSpan.Create(PByte(@FSubPrefix[1]), SizeUInt(Length(FSubPrefix)));
  if SpanStartsWith(SPath, SPrefix) then
    Result := Copy(APath, Length(FSubPrefix) + 1, MaxInt);
end;

procedure TSubVfs.ReraiseSub(E: EVfsError);
begin
  { 把底层错误改写为子视图坐标后原类重抛；非 EVfsError 不经此处 }
  raise EVfsErrorClass(E.ClassType).CreateCtx(E.Op,
    ToSubView(E.Path), E.Message);
end;

function TSubVfs.Exists(const APath: string): Boolean;
begin
  if not VfsValidPath(APath, True) then
    Exit(False);
  Result := FBase.Exists(ToBase(APath));
end;

function TSubVfs.Stat(const APath: string): TStatInfo;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  try
    Result := FBase.Stat(ToBase(APath));
  except
    on E: EVfsError do ReraiseSub(E);
  end;
  Result.Info.Name := ToSubView(Result.Info.Name);
end;

function TSubVfs.List(const ADirPath: string): TEntryArray;
var
  I: SizeUInt;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  try
    Result := FBase.List(ToBase(ADirPath));
  except
    on E: EVfsError do ReraiseSub(E);
  end;
  for I := 0 to SizeUInt(Length(Result)) - 1 do
    Result[I].Name := ToSubView(Result[I].Name);
end;

function TSubVfs.OpenRead(const APath: string): IStream;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  try
    Result := FBase.OpenRead(ToBase(APath));
  except
    on E: EVfsError do ReraiseSub(E);
  end;
end;

function TSubVfs.CaseSensitive: Boolean;
begin
  Result := FBase.CaseSensitive;
end;

end.
