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
  nextpas.core.text.view,
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

  TSubVfs = class(TInterfacedObject, IVfs, IVfsView)
  private
    FBase: IVfs;
    FSubRoot: string;
    FSubPrefix: string;   { FSubRoot + '/' 缓存，identity 时为空，零重复分配 }
    FIdentity: Boolean;   { SubRoot='.' 时直通 }
    function ToBase(const APath: string): string;
    function ToBaseView(const APath: TStringView): string; inline;
    function ToSubView(const APath: string): string; inline;
    procedure ReraiseSub(E: EVfsError);
  public
    constructor Create(const ABase: IVfs; const ASubRoot: string);
    function Exists(const APath: string): Boolean;
    function ExistsView(const APath: TStringView): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function OpenReadView(const APath: TStringView): IStream;
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

{ 视图版坐标换算：单次 ToString 物化后复用 ToBase 单源（含 identity 直通与根映射） }
function TSubVfs.ToBaseView(const APath: TStringView): string; inline;
begin
  Result := ToBase(APath.ToString);
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
  // perf: zero-copy TByteSpan view single-source via VfsSpanFromString->TByteSpan.FromStr inline, bytes.ops SpanStartsWith->MemEqual hot path, no alloc
  SPath := VfsSpanFromString(APath);
  SPrefix := VfsSpanFromString(FSubPrefix);
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

function TSubVfs.ExistsView(const APath: TStringView): Boolean; inline;
var
  V: IVfsView;
  LBase: string;
begin
  { 零拷贝直达：内层支持视图则免物化透传；否则单次物化走 ToBase 单源 }
  if VfsIsRootView(APath) then
    Exit(FBase.Exists(ToBase('.')));
  if not VfsValidPathView(APath, True) then
    Exit(False);
  if FIdentity and Supports(FBase, IVfsView, V) then
    Exit(V.ExistsView(APath));
  LBase := ToBaseView(APath);
  Result := FBase.Exists(LBase);
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

function TSubVfs.OpenReadView(const APath: TStringView): IStream;
var
  V: IVfsView;
  LBase: string;
begin
  { 零拷贝直达：identity 且内层支持视图则免物化透传；
    否则单次物化走 ToBase 单源，错误改写仍是子视图坐标 }
  if not VfsValidPathView(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath.ToString, 'invalid virtual path');
  if FIdentity and Supports(FBase, IVfsView, V) then
  begin
    try
      Result := V.OpenReadView(APath);
    except
      on E: EVfsError do ReraiseSub(E);
    end;
    Exit;
  end;
  LBase := ToBaseView(APath);
  try
    Result := FBase.OpenRead(LBase);
  except
    on E: EVfsError do ReraiseSub(E);
  end;
end;

function TSubVfs.CaseSensitive: Boolean;
begin
  Result := FBase.CaseSensitive;
end;

end.
