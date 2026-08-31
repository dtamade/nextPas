unit nextpas.core.respack.embed;

{** @desc 嵌入工具链库（S4）：目录 → 过滤/映射 → 打包 blob；blob → .inc typed const
  源文本。格式逻辑全部收口 core 侧，CLI（core/tools/respack）只是薄壳。选项面对标
  rust-embed derive 属性与 asar unpack-dir；真实文件系统接触点只有 dirsource
  （输入枚举 + 输出解包 ResPackExtractToDir），本单元零 fs 依赖。

  处理管线（相对路径 = dirsource 枚举出的 '/' 分隔包内相对路径）：
    rel → StripPrefix 剥离（不匹配该前缀的条目剔除）→ 逻辑路径上做 glob 过滤
        → AddPrefix 拼接 → 最终包内路径（ValidPath 校验）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

type
  { 嵌入打包选项；Build 字段透传 writer（去重/hash/digest/输入上限） }
  TResPackEmbedOptions = record
    IncludeGlobs: TStringArray;  { 空 = 全收；对逻辑路径匹配 }
    ExcludeGlobs: TStringArray;  { 任一命中即剔除，胜过 IncludeGlobs }
    StripPrefix: string;         { '' 或以 '/' 结尾，如 'dist/' }
    AddPrefix: string;           { '' 或以 '/' 结尾，如 'assets/' }
    Build: TResPackBuildOptions;
  end;

  { .inc 源文本生成选项 }
  TResPackIncOptions = record
    ConstName: string;     { 必填：ASCII Pascal 标识符（保留字不在此校验） }
    BytesPerLine: Integer; { <=0 取默认 16 }
  end;

const
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = 16;

function ResPackDefaultEmbedOptions: TResPackEmbedOptions; inline;
function ResPackDefaultIncOptions: TResPackIncOptions;

{ ASCII Pascal 标识符判定：首字符字母/下划线，其余字母/数字/下划线 }
function ResPackValidIdent(const AName: string): Boolean;

{ 目录 → blob。过滤后 0 条目 raise EResPackError（空包几乎总是 glob 写错，
  绝不静默产出）；选项非法（前缀不以 '/' 结尾、空 glob 模式等）同样显式报错。 }
function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;

{** blob → Pascal typed const 源文本（纯 ASCII、LF 行尾）。确定性输出：
    同 blob 同参数逐字节一致（test_respack_embed golden 门禁锁定）。
    生成形态（与仓库既有生成式 const 风格一致）：
      const
        NAME_SIZE = N;
        NAME: array[0..NAME_SIZE - 1] of Byte = (
          $XX,... );
    ABlob.Size = 0 或 ConstName 非法 raise EResPackError。
    提示：typed const 载体适合中小包（经验值 < 4MB），大包走 .pack 文件；
    编译时间对比数据见模块 README「嵌入载体」节。 }
function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes;

// 同上，但包成完整可编译单元（AUnitName 必须是合法 Pascal 标识符，
// 不得与 ConstName 相同）。适合不想管理 {$I} 包裹文件的构建管线。
function ResPackEmbedIncUnitSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; const AUnitName: string): TBytes;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs.glob,
  nextpas.core.respack.dirsource,
  nextpas.core.respack.writer;

function ResPackDefaultEmbedOptions: TResPackEmbedOptions;
begin
  Result.IncludeGlobs := nil;
  Result.ExcludeGlobs := nil;
  Result.StripPrefix := '';
  Result.AddPrefix := '';
  Result.Build := ResPackDefaultOptions;
end;

function ResPackDefaultIncOptions: TResPackIncOptions;
begin
  Result.ConstName := '';
  Result.BytesPerLine := RESPACK_INC_DEFAULT_BYTES_PER_LINE;
end;

function ResPackValidIdent(const AName: string): Boolean;
var
  I, N: Integer;
  C: AnsiChar;
begin
  Result := False;
  N := Length(AName);
  if N = 0 then
    Exit;
  C := AName[1];
  if not ((C in ['A'..'Z']) or (C in ['a'..'z']) or (C = '_')) then
    Exit;
  for I := 2 to N do
  begin
    C := AName[I];
    if not ((C in ['A'..'Z']) or (C in ['a'..'z'])
      or (C in ['0'..'9']) or (C = '_')) then
      Exit;
  end;
  Result := True;
end;

function StartsSlash(const S: string): Boolean; inline;
begin
  Result := (Length(S) > 0) and (S[Length(S)] = '/');
end;

procedure CheckGlobList(const AList: TStringArray; const AWhat: string);
var
  I: SizeUInt;
begin
  if SizeUInt(Length(AList)) = 0 then
    Exit;
  for I := 0 to SizeUInt(Length(AList)) - 1 do
    if Length(AList[I]) = 0 then
      raise EResPackError.Create('respack.embed: empty ' + AWhat
        + ' glob pattern');
end;

{ 管线中段：返回 False 表示该条目被过滤/映射规则剔除；
  ARel 入、AOut 出最终包内路径 }
function MapAndFilter(const AOpts: TResPackEmbedOptions;
  const ARel: string; out AOut: string): Boolean;
var
  Logical: string;
  I: SizeUInt;
begin
  Result := False;
  { StripPrefix：不匹配即剔除（语义见单元头注释管线说明） }
  if AOpts.StripPrefix <> '' then
  begin
    if (Length(ARel) <= Length(AOpts.StripPrefix))
      or (Copy(ARel, 1, Length(AOpts.StripPrefix)) <> AOpts.StripPrefix) then
      Exit;
    Logical := Copy(ARel, Length(AOpts.StripPrefix) + 1, MaxInt);
  end
  else
    Logical := ARel;
  if not ResPackValidPath(Logical, True) then
    Exit;

  { glob 过滤在逻辑路径上进行（用户面对的即最终包内相对名，减去 AddPrefix）。
    循环前必须守卫零长度：SizeUInt 无符号下界回绕（README FPC trunk 注意事项） }
  if SizeUInt(Length(AOpts.ExcludeGlobs)) > 0 then
    for I := 0 to SizeUInt(Length(AOpts.ExcludeGlobs)) - 1 do
      if GlobMatch(AOpts.ExcludeGlobs[I], Logical) then
        Exit;
  if SizeUInt(Length(AOpts.IncludeGlobs)) > 0 then
  begin
    for I := 0 to SizeUInt(Length(AOpts.IncludeGlobs)) - 1 do
      if GlobMatch(AOpts.IncludeGlobs[I], Logical) then
      begin
        Result := True;
        Break;
      end;
    if not Result then
      Exit;
  end;

  AOut := AOpts.AddPrefix + Logical;
  if not ResPackValidPath(AOut, True) then
    raise EResPackInvalidPath.Create('respack.embed: mapped path invalid "'
      + AOut + '"');
  Result := True;
end;

function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;
var
  Src: TResPackDirEntries;
  Kept: TResPackInputArray;
  I, N: SizeUInt;
  Mapped: string;
begin
  if (AOpts.StripPrefix <> '') and (not StartsSlash(AOpts.StripPrefix)) then
    raise EResPackError.Create('respack.embed: StripPrefix must be empty or ' +
      'end with "/" ("' + AOpts.StripPrefix + '")');
  if (AOpts.AddPrefix <> '') and (not StartsSlash(AOpts.AddPrefix)) then
    raise EResPackError.Create('respack.embed: AddPrefix must be empty or ' +
      'end with "/" ("' + AOpts.AddPrefix + '")');
  CheckGlobList(AOpts.IncludeGlobs, 'include');
  CheckGlobList(AOpts.ExcludeGlobs, 'exclude');

  { 不经回调过滤：dirsource 的 Include 形态要求把选项捕获进匿名函数，
    FPC trunk 对跨帧闭包捕获的支持不可靠。改为全枚举 + 单趟过滤映射；
    Src.Contents 是内容锚点（S4 修复），存活至本函数尾，覆盖 Build 读窗 }
  Src := ResPackEntriesFromDir(ASourceDir);
  N := SizeUInt(Length(Src.Entries));
  Kept := nil;
  if N > 0 then
    for I := 0 to N - 1 do
      if MapAndFilter(AOpts, Src.Entries[I].Path, Mapped) then
      begin
        SetLength(Kept, SizeInt(SizeUInt(Length(Kept)) + 1));
        Kept[SizeUInt(Length(Kept)) - 1] := Src.Entries[I];
        Kept[SizeUInt(Length(Kept)) - 1].Path := Mapped;
      end;
  if SizeUInt(Length(Kept)) = 0 then
    raise EResPackError.Create('respack.embed: no entries matched after ' +
      'filter/mapping (source "' + ASourceDir + '")');
  Result := ResPackBuild(Kept, AOpts.Build);
end;

function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes;
const
  HEX: array[0..15] of AnsiChar = '0123456789ABCDEF';
var
  Name: string;
  PerLine, LineCols, I: Integer;
  N: SizeUInt;
  Cap: SizeUInt;
  OutBuf: TBytes;
  W: PByte;
  B: Byte;

  procedure EmitStr(const S: string);
  var
    J: Integer;
  begin
    for J := 1 to Length(S) do
    begin
      W^ := Byte(S[J]);
      Inc(W);
    end;
  end;

  procedure EmitCh(const C: AnsiChar); inline;
  begin
    W^ := Byte(C);
    Inc(W);
  end;

begin
  Name := AOpts.ConstName;
  if not ResPackValidIdent(Name) then
    raise EResPackError.Create('respack.embed: ConstName must be a Pascal ' +
      'identifier ("' + Name + '")');
  if ABlob.Data = nil then
    raise EResPackError.Create('respack.embed: blob is nil');
  if ABlob.Size = 0 then
    raise EResPackError.Create('respack.embed: blob is empty');
  PerLine := AOpts.BytesPerLine;
  if PerLine <= 0 then
    PerLine := RESPACK_INC_DEFAULT_BYTES_PER_LINE;

  { 容量上界：头注释 + 声明行 + 每字节至多 ", $XX" 5 列 + 行尾换行 }
  N := ABlob.Size;
  Cap := 256 + SizeUInt(Length(Name)) * 4 + 40
    + N * 5 + (N div SizeUInt(PerLine) + 2) * 2;
  SetLength(OutBuf, Cap);
  W := @OutBuf[0];

  EmitStr('{ generated by rp_pack / nextpas.core.respack embed toolchain. }'
    + #10 + '{ do not edit; regenerate instead. deterministic output is    }'
    + #10 + '{ locked by the test_respack_embed golden gate.               }'
    + #10);
  EmitStr('const'#10'  ');
  EmitStr(Name);
  EmitStr('_SIZE = ');
  EmitStr(IntToStr(SizeInt(N)));
  EmitStr(';'#10'  ');
  EmitStr(Name);
  EmitStr(': array[0..');
  EmitStr(Name);
  EmitStr('_SIZE - 1] of Byte = ('#10);

  LineCols := 0;
  for I := 0 to SizeInt(N) - 1 do
  begin
    if LineCols = 0 then
      EmitStr('  ');
    B := ABlob.Data[I];
    EmitCh('$');
    EmitCh(HEX[B shr 4]);
    EmitCh(HEX[B and $0F]);
    if I = SizeInt(N) - 1 then
      Break;
    EmitCh(',');
    Inc(LineCols);
    if LineCols >= PerLine then
    begin
      EmitCh(#10);
      LineCols := 0;
    end;
  end;
  EmitStr(#10'  );'#10);

  SetLength(OutBuf, W - @OutBuf[0]);
  Result := OutBuf;
end;

function IdentEqualCI(const AA, AB: string): Boolean;
var
  I, N: Integer;
begin
  Result := False;
  N := Length(AA);
  if N <> Length(AB) then
    Exit;
  for I := 1 to N do
    if UpCase(AA[I]) <> UpCase(AB[I]) then
      Exit;
  Result := True;
end;

function ResPackEmbedIncUnitSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; const AUnitName: string): TBytes;
var
  Body, Head, Tail: TBytes;
begin
  if not ResPackValidIdent(AUnitName) then
    raise EResPackError.Create('respack.embed: UnitName must be a Pascal ' +
      'identifier ("' + AUnitName + '")');
  if IdentEqualCI(AUnitName, AOpts.ConstName) then
    raise EResPackError.Create('respack.embed: UnitName must differ from ' +
      'ConstName ("' + AUnitName + '")');
  Body := ResPackEmbedIncSource(ABlob, AOpts);
  Head := StringToBytes('unit ' + AUnitName + ';' + #10 +
    '{$mode objfpc}{$H+}' + #10 + #10 + 'interface' + #10 + #10);
  Tail := StringToBytes(#10 + 'implementation' + #10 + #10 + 'end.' + #10);
  Result := BytesConcatMany([Head, Body, Tail]);
end;

end.
