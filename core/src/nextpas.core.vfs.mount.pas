unit nextpas.core.vfs.mount;

{** @desc mount 视图：多 IVfs 按前缀挂载的只读复合视图（Go fs.FS 组合对等物）。
  完整性：补齐 respack/vfs 对多源资产聚合的最后一块（P2），超越 Go embed 单包。
  INV-M1：挂载表按前缀长度降序（最长匹配），'.' 前缀表根直通。
  错误语义：Op/Path 保持调用方视角，复用 sub 同款改写策略。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

type
  TVfsMountEntry = record
    Prefix: string; { '' 或 '.' 表根挂载；否则合法虚拟路径如 'assets' }
    Fs: IVfs;
  end;
  TVfsMountArray = array of TVfsMountEntry;

{ AMounts 至少1项；Prefix 必须 ValidPath(AllowRoot True) 且去重；Fs 非空。
  '.' 与 '' 等价为根；根挂载与前缀挂载不可混搭重复（根唯一）。 }
function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs;

implementation

uses
  nextpas.core.base.utils;

type
  TMountedVfs = class(TInterfacedObject, IVfs)
  private
    FMounts: TVfsMountArray;
    FHasRoot: Boolean;
    FRootFs: IVfs;
    function FindMount(const APath: string; out ARemain: string; out AFs: IVfs): Boolean;
    function IsMountPoint(const APath: string): Boolean;
  public
    constructor Create(const AMounts: array of TVfsMountEntry);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
  end;

function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs;
begin
  Result := TMountedVfs.Create(AMounts);
end;

function NormalizePrefix(const S: string): string; inline;
var
  L: Integer;
begin
  Result := S;
  if (Result = '') or VfsIsRoot(Result) then Exit('.');
  L := Length(Result);
  while (L > 0) and (Result[L] = '/') do Dec(L);
  if L <> Length(Result) then SetLength(Result, L);
end;

constructor TMountedVfs.Create(const AMounts: array of TVfsMountEntry);
var
  I, J: Integer;
  P: string;
begin
  inherited Create;
  if Length(AMounts) = 0 then
    raise EVfsError.CreateCtx('mount', '', 'mounted vfs requires at least one mount');
  SetLength(FMounts, Length(AMounts));
  FHasRoot := False;
  for I := 0 to High(AMounts) do
  begin
    P := NormalizePrefix(AMounts[I].Prefix);
    if not VfsValidPath(P, True) then
      raise EVfsInvalidPath.CreateCtx('mount', P, 'invalid mount prefix');
    if AMounts[I].Fs = nil then
      raise EVfsError.CreateCtx('mount', P, 'mount fs must not be nil');
    for J := 0 to I - 1 do
      if FMounts[J].Prefix = P then
        raise EVfsError.CreateCtx('mount', P, 'duplicate mount prefix');
    FMounts[I].Prefix := P;
    FMounts[I].Fs := AMounts[I].Fs;
    if VfsIsRoot(P) then
    begin
      if FHasRoot then
        raise EVfsError.CreateCtx('mount', P, 'duplicate root mount');
      FHasRoot := True;
      FRootFs := AMounts[I].Fs;
    end;
  end;
  // 最长匹配优先：按长度降序
  for I := 0 to High(FMounts) - 1 do
    for J := I + 1 to High(FMounts) do
      if Length(FMounts[J].Prefix) > Length(FMounts[I].Prefix) then
      begin
        P := FMounts[I].Prefix;
        FMounts[I].Prefix := FMounts[J].Prefix;
        FMounts[J].Prefix := P;
        // swap Fs: 用临时 FRootFs 承载
        FRootFs := FMounts[I].Fs;
        FMounts[I].Fs := FMounts[J].Fs;
        FMounts[J].Fs := FRootFs;
      end;
  // re-evaluate root after sort
  FHasRoot := False;
  FRootFs := nil;
  for I := 0 to High(FMounts) do
    if VfsIsRoot(FMounts[I].Prefix) then
    begin
      FHasRoot := True;
      FRootFs := FMounts[I].Fs;
      Break;
    end;
end;

function TMountedVfs.IsMountPoint(const APath: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FMounts) do
    if FMounts[I].Prefix = APath then Exit(True);
  Result := False;
end;

function TMountedVfs.FindMount(const APath: string; out ARemain: string; out AFs: IVfs): Boolean;
var
  I: Integer;
  Pre: string;
begin
  if VfsIsRoot(APath) then
  begin
    // 根请求不直接映射到子 Fs，由调用方按需分发
    ARemain := '.';
    AFs := nil;
    Exit(False);
  end;
  for I := 0 to High(FMounts) do
  begin
    Pre := FMounts[I].Prefix;
    if VfsIsRoot(Pre) then Continue;
    if APath = Pre then
    begin
      ARemain := '.';
      AFs := FMounts[I].Fs;
      Exit(True);
    end;
    if (Length(APath) > Length(Pre)) and (APath[Length(Pre) + 1] = '/')
      and (Copy(APath, 1, Length(Pre)) = Pre) then
    begin
      ARemain := Copy(APath, Length(Pre) + 2, MaxInt);
      AFs := FMounts[I].Fs;
      Exit(True);
    end;
  end;
  // 尝试根挂载兜底
  if FHasRoot then
  begin
    ARemain := APath;
    AFs := FRootFs;
    Exit(True);
  end;
  Result := False;
end;

function TMountedVfs.Exists(const APath: string): Boolean;
var
  Rem: string;
  Fs: IVfs;
begin
  if not VfsValidPath(APath, True) then Exit(False);
  if VfsIsRoot(APath) then Exit(True);
  if IsMountPoint(APath) then Exit(True);
  if FindMount(APath, Rem, Fs) then
    Exit(Fs.Exists(Rem));
  Result := False;
end;

function TMountedVfs.Stat(const APath: string): TStatInfo;
var
  Rem: string;
  Fs: IVfs;
  I: Integer;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
  begin
    Result.Info.Name := '.';
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
    Exit;
  end;
  if IsMountPoint(APath) then
  begin
    // 挂载点视为目录（底层须为目录，已由子 Fs 保证）
    Result.Info.Name := APath;
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
    Exit;
  end;
  if FindMount(APath, Rem, Fs) then
  begin
    Result := Fs.Stat(Rem);
    Result.Info.Name := APath;
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

function TMountedVfs.List(const ADirPath: string): TEntryArray;
var
  Rem: string;
  Fs: IVfs;
  I, OutN: Integer;
  Seen: array of string;
  Child: string;
  SL: SizeInt;
  BaseList: TEntryArray;
  J: Integer;
  Already: Boolean;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if VfsIsRoot(ADirPath) then
  begin
    // 根：合并所有挂载点的顶层 List
    if FHasRoot and (Length(FMounts) = 1) then
      Exit(FRootFs.List('.'));
    // 收集挂载点名作为直接子
    SetLength(Result, Length(FMounts));
    OutN := 0;
    for I := 0 to High(FMounts) do
      if not VfsIsRoot(FMounts[I].Prefix) then
      begin
        // 顶层名 = Prefix 的首段
        SL := Pos('/', FMounts[I].Prefix);
        if SL > 0 then Child := Copy(FMounts[I].Prefix, 1, SL - 1)
        else Child := FMounts[I].Prefix;
        // 去重
        Already := False;
        for J := 0 to OutN - 1 do
          if Result[J].Name = Child then begin Already := True; Break; end;
        if Already then Continue;
        Result[OutN].Name := Child;
        Result[OutN].Size := 0;
        Result[OutN].ModTime := 0;
        Result[OutN].IsDir := True;
        Inc(OutN);
      end;
    // 若有根挂载，合并其根 List 去重
    if FHasRoot then
    begin
      BaseList := FRootFs.List('.');
      for I := 0 to High(BaseList) do
      begin
        Already := False;
        for J := 0 to OutN - 1 do
          if Result[J].Name = BaseList[I].Name then begin Already := True; Break; end;
        if Already then Continue;
        if OutN >= Length(Result) then SetLength(Result, OutN + 1);
        Result[OutN] := BaseList[I];
        Inc(OutN);
      end;
    end;
    SetLength(Result, OutN);
    VfsSortEntries(Result);
    Exit;
  end;
  if IsMountPoint(ADirPath) then
  begin
    for I := 0 to High(FMounts) do
      if FMounts[I].Prefix = ADirPath then
        Exit(FMounts[I].Fs.List('.'));
  end;
  if FindMount(ADirPath, Rem, Fs) then
    Exit(Fs.List(Rem));
  // 若是前缀的父目录，需聚合子挂载点
  // 例如 mounts: a/b, a/c  => List('a') 应返回 b,c
  OutN := 0;
  SetLength(Result, Length(FMounts));
  for I := 0 to High(FMounts) do
  begin
    if VfsIsRoot(FMounts[I].Prefix) then Continue;
    if (Length(FMounts[I].Prefix) > Length(ADirPath))
      and (FMounts[I].Prefix[Length(ADirPath) + 1] = '/')
      and (Copy(FMounts[I].Prefix, 1, Length(ADirPath)) = ADirPath) then
    begin
      Child := Copy(FMounts[I].Prefix, Length(ADirPath) + 2, MaxInt);
      SL := Pos('/', Child);
      if SL > 0 then Child := Copy(Child, 1, SL - 1);
      Already := False;
      for J := 0 to OutN - 1 do
        if Result[J].Name = Child then begin Already := True; Break; end;
      if Already then Continue;
      Result[OutN].Name := Child;
      Result[OutN].Size := 0;
      Result[OutN].ModTime := 0;
      Result[OutN].IsDir := True;
      Inc(OutN);
    end;
  end;
  if OutN > 0 then
  begin
    SetLength(Result, OutN);
    VfsSortEntries(Result);
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
end;

function TMountedVfs.OpenRead(const APath: string): IStream;
var
  Rem: string;
  Fs: IVfs;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if VfsIsRoot(APath) or IsMountPoint(APath) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  if FindMount(APath, Rem, Fs) then
    Exit(Fs.OpenRead(Rem));
  raise EVfsNotFound.CreateCtx('open', APath, 'not found');
end;

function TMountedVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

end.
