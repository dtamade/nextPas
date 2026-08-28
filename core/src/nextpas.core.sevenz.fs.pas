unit nextpas.core.sevenz.fs;

{**
 * nextpas.core.sevenz.fs - 7z 文件系统联邦层
 *
 * 在 core.sevenz 与 core.fs 之间提供零样板桥接：
 *  - 写端：AddFileFromFs / AddTree 将宿主文件/目录树直接挂入 ISevenZWriter
 *   （基于 IReader 流式路径，声明尺寸取 Stat.Size，时间取 ModTime 秒）
 *  - 读端：ExtractToFs / ExtractAllToFs 将条目落地到宿主文件系统
 *    （目录自动 MkdirAll，文件经 ExtractTo 流式写入）
 *
 * 本单元为 L2 联邦扩展（同层单向依赖 fs → 不成环），与核心 sevenz.writer/reader
 * 解耦，复用 AddFileFromReader / ExtractTo 既有路径。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sevenz.intf;

{ 写端：宿主文件 → 归档条目 }
procedure SevenZAddFileFromFs(const AWriter: ISevenZWriter;
  const AHostPath, AEntryName: string);
procedure SevenZAddFileFromFsWithTime(const AWriter: ISevenZWriter;
  const AHostPath, AEntryName: string; AUseFsMTime: Boolean);
procedure SevenZAddTree(const AWriter: ISevenZWriter;
  const AHostDir, AEntryPrefix: string);
procedure SevenZAddTreeWithFilter(const AWriter: ISevenZWriter;
  const AHostDir, AEntryPrefix: string; const AInclude: string);

{ 读端：归档条目 → 宿主文件 }
function SevenZExtractToFs(const AReader: ISevenZReader; AIndex: Integer;
  const AHostPath: string): Int64;
procedure SevenZExtractAllToFs(const AReader: ISevenZReader;
  const ABaseDir: string);
function SevenZExtractByPrefixToFs(const AReader: ISevenZReader;
  const APrefix, ABaseDir: string): Integer;
function SevenZExtractBySuffixToFs(const AReader: ISevenZReader;
  const ASuffix, ABaseDir: string): Integer;
function SevenZExtractByGlobToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string): Integer;
function SevenZTryExtractByGlobToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string; out AError: string): Boolean;
function SevenZExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader;
  const APrefix, ABaseDir: string): Integer;
function SevenZExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader;
  const ASuffix, ABaseDir: string): Integer;
function SevenZExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string): Integer;
function SevenZTryExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string; out AError: string): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.fs.intf,
  nextpas.core.sevenz.base;

type
  TTreeCtx = record
    Writer: ISevenZWriter;
    HostDir: string;
    Prefix: string;
    IncludePat: string;
  end;
  PTreeCtx = ^TTreeCtx;

function SevenZTreeWalkCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PTreeCtx;
  LRel, LName: string;
begin
  Ctx := PTreeCtx(AUserData);
  if AErr <> nil then
    raise EIOError.CreateFmt('SevenZAddTree walk error at "%s": %s', [APath, AErr.Message]);
  if SameFile(APath, Ctx^.HostDir) then
    Exit(True);
  if Ctx^.IncludePat <> '' then
    if not PathMatch(Ctx^.IncludePat, PathBase(APath)) then
      Exit(True);
  LRel := PathRelative(Ctx^.HostDir, APath);
  if Ctx^.Prefix <> '' then
    LName := PathJoin([Ctx^.Prefix, LRel])
  else
    LName := LRel;
  if (LName <> '') and (LName[1] = '.') and (Length(LName) > 1) and (LName[2] = '/') then
    Delete(LName, 1, 2);
  if LName = '' then
    Exit(True);
  if AInfo.IsDir then
    Ctx^.Writer.AddDirectory(LName)
  else if AInfo.FileType = ftRegular then
    SevenZAddFileFromFs(Ctx^.Writer, APath, LName);
  Result := True;
end;

procedure SevenZAddFileFromFs(const AWriter: ISevenZWriter;
  const AHostPath, AEntryName: string);
begin
  SevenZAddFileFromFsWithTime(AWriter, AHostPath, AEntryName, True);
end;

procedure SevenZAddFileFromFsWithTime(const AWriter: ISevenZWriter;
  const AHostPath, AEntryName: string; AUseFsMTime: Boolean);
var
  LFile: IFile;
  LInfo: TFileInfo;
  LSize: UInt64;
  LMTimeSec: Int64;
begin
  if AWriter = nil then
    raise EArgumentError.Create('SevenZAddFileFromFs: AWriter is nil');
  if AHostPath = '' then
    raise EArgumentError.Create('SevenZAddFileFromFs: AHostPath is empty');
  LInfo := Stat(AHostPath);
  if LInfo.IsDir then
    raise EArgumentError.CreateFmt('SevenZAddFileFromFs: "%s" is a directory', [AHostPath]);
  LFile := Open(AHostPath, [fmRead]);
  if LInfo.Size < 0 then
    LSize := 0
  else
    LSize := UInt64(LInfo.Size);
  if AUseFsMTime then
  begin
    LMTimeSec := LInfo.ModTime div 1000000000;
    AWriter.AddFileFromReaderWithTime(AEntryName, LFile as IReader, LSize, LMTimeSec);
  end
  else
    AWriter.AddFileFromReader(AEntryName, LFile as IReader, LSize);
end;

procedure SevenZAddTree(const AWriter: ISevenZWriter;
  const AHostDir, AEntryPrefix: string);
begin
  SevenZAddTreeWithFilter(AWriter, AHostDir, AEntryPrefix, '');
end;

procedure SevenZAddTreeWithFilter(const AWriter: ISevenZWriter;
  const AHostDir, AEntryPrefix: string; const AInclude: string);
var
  Ctx: TTreeCtx;
begin
  if AWriter = nil then
    raise EArgumentError.Create('SevenZAddTree: AWriter is nil');
  if AHostDir = '' then
    raise EArgumentError.Create('SevenZAddTree: AHostDir is empty');
  if not IsDir(AHostDir) then
    raise EArgumentError.CreateFmt('SevenZAddTree: "%s" is not a directory', [AHostDir]);
  Ctx.Writer := AWriter;
  Ctx.HostDir := AHostDir;
  Ctx.Prefix := PathClean(AEntryPrefix);
  if (Ctx.Prefix = '.') or (Ctx.Prefix = '/') then
    Ctx.Prefix := '';
  Ctx.IncludePat := AInclude;
  WalkEx(AHostDir, @SevenZTreeWalkCallback, @Ctx);
end;

function SevenZExtractToFs(const AReader: ISevenZReader; AIndex: Integer;
  const AHostPath: string): Int64;
var
  LInfo: TSevenZEntryInfo;
  LDir: string;
  LFile: IFile;
begin
  if AReader = nil then
    raise EArgumentError.Create('SevenZExtractToFs: AReader is nil');
  if AHostPath = '' then
    raise EArgumentError.Create('SevenZExtractToFs: AHostPath is empty');
  LInfo := AReader.Entry(AIndex);
  if LInfo.Kind = sekDirectory then
  begin
    MkdirAll(AHostPath);
    Result := 0;
    Exit;
  end;
  if LInfo.Size = 0 then
  begin
    LDir := PathDir(AHostPath);
    if LDir <> '' then
      MkdirAll(LDir);
    { 空文件：创建 0 字节文件 }
    LFile := Create(AHostPath);
    LFile.Close;
    Result := 0;
    if LInfo.HasMTime then
      Chtimes(AHostPath, LInfo.MTimeUnixSec * 1000000000, LInfo.MTimeUnixSec * 1000000000);
    Exit;
  end;
  LDir := PathDir(AHostPath);
  if LDir <> '' then
    MkdirAll(LDir);
  LFile := Create(AHostPath);
  try
    Result := AReader.ExtractTo(LFile as IWriter, AIndex);
  finally
    LFile.Close;
  end;
  if LInfo.HasMTime then
    Chtimes(AHostPath, LInfo.MTimeUnixSec * 1000000000, LInfo.MTimeUnixSec * 1000000000);
end;

procedure FlushExtractedToFs(const AExt: TSevenZExtractedArray; const ABaseDir: string);
var I: Integer; LPath: string; LFile: IFile;
begin
  for I:=0 to High(AExt) do
  begin
    LPath := PathJoin([ABaseDir, AExt[I].Info.Name]);
    if AExt[I].Info.Kind = sekDirectory then MkdirAll(LPath)
    else
    begin
      if AExt[I].Data = nil then
      begin
        if PathDir(LPath) <> '' then MkdirAll(PathDir(LPath));
        LFile := Create(LPath); LFile.Close;
      end
      else
      begin
        if PathDir(LPath) <> '' then MkdirAll(PathDir(LPath));
        WriteFile(LPath, AExt[I].Data);
      end;
      if AExt[I].Info.HasMTime then
        Chtimes(LPath, AExt[I].Info.MTimeUnixSec*1000000000, AExt[I].Info.MTimeUnixSec*1000000000);
    end;
  end;
end;

procedure SevenZExtractAllToFs(const AReader: ISevenZReader;
  const ABaseDir: string);
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then
    raise EArgumentError.Create('SevenZExtractAllToFs: AReader is nil');
  if ABaseDir = '' then
    raise EArgumentError.Create('SevenZExtractAllToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractAll;
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZExtractByPrefixToFs(const AReader: ISevenZReader;
  const APrefix, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractByPrefixToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractByPrefixToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractByPrefix(APrefix);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZExtractBySuffixToFs(const AReader: ISevenZReader;
  const ASuffix, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractBySuffixToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractBySuffixToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractBySuffix(ASuffix);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZExtractByGlobToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractByGlobToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractByGlobToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractByGlob(APattern);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZTryExtractByGlobToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string; out AError: string): Boolean;
var Ext: TSevenZExtractedArray;
begin
  AError := ''; Result := False;
  if AReader = nil then begin AError := 'AReader is nil'; Exit(False); end;
  if ABaseDir = '' then begin AError := 'ABaseDir is empty'; Exit(False); end;
  try
    MkdirAll(ABaseDir);
    if not AReader.TryExtractByGlobWithError(APattern, Ext, AError) then Exit(False);
    FlushExtractedToFs(Ext, ABaseDir);
    Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; Result := False; end; end;
end;

function SevenZExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader;
  const APrefix, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractByPrefixIgnoreCaseToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractByPrefixIgnoreCaseToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractByPrefixIgnoreCase(APrefix);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader;
  const ASuffix, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractBySuffixIgnoreCaseToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractBySuffixIgnoreCaseToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractBySuffixIgnoreCase(ASuffix);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string): Integer;
var Ext: TSevenZExtractedArray;
begin
  if AReader = nil then raise EArgumentError.Create('SevenZExtractByGlobIgnoreCaseToFs: AReader is nil');
  if ABaseDir = '' then raise EArgumentError.Create('SevenZExtractByGlobIgnoreCaseToFs: ABaseDir is empty');
  MkdirAll(ABaseDir);
  Ext := AReader.ExtractByGlobIgnoreCase(APattern);
  Result := Length(Ext);
  FlushExtractedToFs(Ext, ABaseDir);
end;

function SevenZTryExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader;
  const APattern, ABaseDir: string; out AError: string): Boolean;
var Ext: TSevenZExtractedArray;
begin
  AError := ''; Result := False;
  if AReader = nil then begin AError := 'AReader is nil'; Exit(False); end;
  if ABaseDir = '' then begin AError := 'ABaseDir is empty'; Exit(False); end;
  try
    MkdirAll(ABaseDir);
    if not AReader.TryExtractByGlobIgnoreCaseWithError(APattern, Ext, AError) then Exit(False);
    FlushExtractedToFs(Ext, ABaseDir);
    Result := True;
  except on E: Exception do begin AError := E.ClassName+': '+E.Message; Result := False; end; end;
end;

end.
