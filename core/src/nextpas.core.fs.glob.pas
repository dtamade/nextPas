unit nextpas.core.fs.glob;
{**
 * @desc Glob 模式匹配：纯字符串匹配 + 文件系统 glob 遍历。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{**
 * @desc 检查文件名是否匹配 glob 模式
 *
 * @params
 *   APattern  glob 模式（支持 *, ?, [abc], [a-z], [^abc], [!abc], **）
 *   AName     待匹配的字符串（可含路径分隔符）
 *
 * @return 是否匹配
 *
 * @note 大小写敏感；* 不跨路径分隔符；** 匹配任意目录层级
 *}
function GlobMatch(const APattern, AName: string): Boolean;

{**
 * @desc 在指定目录下匹配 glob 模式
 *
 * @params
 *   ADir      根目录
 *   APattern  glob 模式（可含路径分隔符和 **）
 *
 * @return 匹配的文件路径数组（排序）
 *}
function FsGlob(const ADir, APattern: string): TStringArray; overload;

{**
 * @desc 在当前目录下匹配 glob 模式
 *
 * @desc 等同于 FsGlob('.', APattern)
 *}
function FsGlob(const APattern: string): TStringArray; overload;

{** @desc 非递归列出目录中匹配模式的文件名（门面 Glob 单源实现） *}
function Glob(const ADir, APattern: string): TStringArray;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.text.strings;

{ GlobMatch — thin forward to L1 single source (text.strings):
  fs.glob 不再自含匹配算法，仅保留文件系统遍历封装。
  复用 bytes.ops/CompareOrdered 思想：PChar 零拷贝视图 + inline 判定，O(pat×name) 确界，无指数回溯。 }
function GlobMatch(const APattern, AName: string): Boolean; inline;
begin
  Result := nextpas.core.text.strings.GlobMatch(APattern, AName);
end;

{ FsGlob — file system glob }

type
  TFsGlobState = record
    Dir: string;
    DirLen: Integer;
    Pattern: string;
    Results: TStringArray;
    Count: Integer;
  end;
  PFsGlobState = ^TFsGlobState;

function FsGlobWalkCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  LState: PFsGlobState;
  LRelPath: string;
begin
  LState := PFsGlobState(AUserData);
  Result := True;
  if AErr <> nil then
    Exit;
  if AInfo.IsDir then
    Exit;
  { Compute relative path from the root dir }
  if Length(APath) > LState^.DirLen then
    LRelPath := Copy(APath, LState^.DirLen + 1, MaxInt)
  else
    LRelPath := APath;
  if GlobMatch(LState^.Pattern, LRelPath) then
  begin
    if LState^.Count >= Length(LState^.Results) then
    begin
      if Length(LState^.Results) = 0 then
        SetLength(LState^.Results, 16)
      else
        SetLength(LState^.Results, Length(LState^.Results) * 2);
    end;
    LState^.Results[LState^.Count] := APath;
    Inc(LState^.Count);
  end;
end;

procedure SortStrings(var A: TStringArray; ACount: Integer);
var
  LI, LJ: Integer;
  LTmp: string;
begin
  for LI := 1 to ACount - 1 do
  begin
    LTmp := A[LI];
    LJ := LI;
    while (LJ > 0) and (A[LJ - 1] > LTmp) do
    begin
      A[LJ] := A[LJ - 1];
      Dec(LJ);
    end;
    A[LJ] := LTmp;
  end;
end;

function FsGlob(const ADir, APattern: string): TStringArray;
var
  LState: TFsGlobState;
begin
  LState.Dir := FsPathTrimSep(ADir) + '/';
  LState.DirLen := Length(LState.Dir);
  LState.Pattern := APattern;
  LState.Results := nil;
  LState.Count := 0;

  FsWalkEx(ADir, @FsGlobWalkCallback, @LState);

  SortStrings(LState.Results, LState.Count);
  SetLength(LState.Results, LState.Count);
  Result := LState.Results;
end;

function FsGlob(const APattern: string): TStringArray;
begin
  Result := FsGlob('.', APattern);
end;

function Glob(const ADir, APattern: string): TStringArray;
var
  LEntries: TDirEntryArray;
  LCount, I: Integer;
begin
  Result := nil;
  try
    LEntries := FsReadDir(ADir);
  except
    on E: ENotFoundError do
      Exit;
  end;
  LCount := 0;
  for I := 0 to High(LEntries) do
  begin
    if FsPathMatch(APattern, LEntries[I].Name) then
    begin
      if LCount >= Length(Result) then
      begin
        if Length(Result) = 0 then
          SetLength(Result, 16)
        else
          SetLength(Result, Length(Result) * 2);
      end;
      Result[LCount] := FsPathJoin([ADir, LEntries[I].Name]);
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

end.
