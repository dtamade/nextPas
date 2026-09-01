unit nextpas.core.respack.embed;

{** @desc 嵌入工具链库（S4）：blob → .inc typed const 源文本。格式逻辑全部收口 core 侧，
  CLI（core/tools/respack）只是薄壳。本单元仅依赖 L1 text.strings/text.char/
  text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、零文件系统依赖，PChar 零拷贝
  视图 + inline 热路径）+ respack.limits 阈值策略单源（4MiB 策略集中、可配置 MaxBlobBytes、
  前置拒绝单源 ResPackRequireIncSize）+ bytes.ops 单源（WriteStr/组装 BytesCopy inline
  零拷贝，IncUnit 单次 SetLength+分段 BytesCopy 与 writer.builder GetMem(Total)单源收敛，
  通用文本组装单源，替代二次分配拼接），纯内存可复用（零 FS/零 writer/
  零 dirsource 依赖，目录 → 过滤/映射 → 打包 blob 的 IO 管线收口于
  respack.dirsource（L2 FS 缝），唯一 L2→L2 FS seam）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.respack.limits;

type
  { 嵌入打包选项；Build 字段透传 writer（去重/hash/digest/输入上限） }
  TResPackEmbedOptions = record
    IncludeGlobs: TStringArray;  { 空 = 全收；对逻辑路径匹配 }
    ExcludeGlobs: TStringArray;  { 任一命中即剔除，胜过 IncludeGlobs }
    StripPrefix: string;         { '' 或以 '/' 结尾，如 'dist/' }
    AddPrefix: string;           { '' 或以 '/' 结尾，如 'assets/' }
    Build: TResPackBuildOptions;
  end;

  { .inc 源文本生成选项；MaxBlobBytes=0 取默认阈值 }
  TResPackIncOptions = record
    ConstName: string;     { 必填：ASCII Pascal 标识符（保留字不在此校验） }
    BytesPerLine: Integer; { <=0 取默认 16 }
    MaxBlobBytes: SizeUInt; { 0=默认 4MiB；显式可覆盖，策略单源于 respack.limits }
  end;

const
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.respack.limits.RESPACK_INC_DEFAULT_BYTES_PER_LINE;
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.respack.limits.RESPACK_INC_MAX_BLOB_BYTES; { 兼容别名，单源于 respack.limits；经验阈值 <4MiB 走 .inc }

function ResPackDefaultEmbedOptions: TResPackEmbedOptions; inline;
function ResPackDefaultIncOptions: TResPackIncOptions;

{ ASCII Pascal 标识符判定：首字符字母/下划线，其余字母/数字/下划线 }
function ResPackValidIdent(const AName: string): Boolean;

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
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.encoding.hex,
  nextpas.core.exception,
  nextpas.core.text.char,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.text.view;

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
  Result.MaxBlobBytes := RESPACK_INC_MAX_BLOB_BYTES;
end;

function ResPackValidIdent(const AName: string): Boolean;
var
  I, N: Integer;
  C: Byte;
begin
  Result := False;
  N := Length(AName);
  if N = 0 then
    Exit;
  C := Byte(AName[1]);
  if not (IsAlpha(C) or (C = Byte('_'))) then
    Exit;
  for I := 2 to N do
  begin
    C := Byte(AName[I]);
    if not (IsAlphaNum(C) or (C = Byte('_'))) then
      Exit;
  end;
  Result := True;
end;

procedure CheckedAdd(var AAcc: SizeUInt; const ADelta: SizeUInt; const AMsg: string); inline;
begin
  if not TryAddSizeUInt(AAcc, ADelta, AAcc) then
    raise EResPackTooLarge.Create(AMsg);
end;

procedure CheckedMul(const ALeft, ARight: SizeUInt; var ARes: SizeUInt; const AMsg: string); inline;
begin
  if not TryMulSizeUInt(ALeft, ARight, ARes) then
    raise EResPackTooLarge.Create(AMsg);
end;

function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes;
var
  Name: string;
  PerLine, LineCols: Integer;
  I: SizeInt;
  N: SizeUInt;
  Cap, LTmp: SizeUInt;
  OutBuf: TBytes;
  W: PByte;
  B: Byte;
  PData: PByte;

  procedure WriteStr(const S: string); inline;
  var
    L: SizeInt;
  begin
    L := Length(S);
    if L = 0 then
      Exit;
    // bytes.ops.BytesCopy 单源零拷贝（inline 单 Move），禁止直调 Move 破坏单源纪律
    BytesCopy(W, PAnsiChar(S), SizeUInt(L));
    Inc(W, L);
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

  { 容量上界：头注释 + 声明行 + 每字节至多 ", $XX" 5 列 + 行尾换行；SizeUInt 溢出保护 — 单源 Checked* helper（inline 零拷贝，owner base.utils） }
  N := ABlob.Size;
  // 阈值前置拒绝单源于 respack.limits（inline 零拷贝，0 零值取默认 4MiB，避免两处硬编码重复与超大临时分配）
  ResPackRequireIncSize(N, ResPackEffectiveIncLimit(AOpts.MaxBlobBytes));
  Cap := 256;
  CheckedMul(SizeUInt(Length(Name)), 4, LTmp, 'respack.embed: ConstName too long');
  CheckedAdd(Cap, LTmp, 'respack.embed: capacity overflow');
  CheckedAdd(Cap, 40, 'respack.embed: capacity overflow');
  CheckedMul(N, 5, LTmp, 'respack.embed: blob too large');
  CheckedAdd(Cap, LTmp, 'respack.embed: capacity overflow');
  LTmp := N div SizeUInt(PerLine);
  CheckedAdd(LTmp, 2, 'respack.embed: capacity overflow');
  CheckedMul(LTmp, 2, LTmp, 'respack.embed: capacity overflow');
  CheckedAdd(Cap, LTmp, 'respack.embed: capacity overflow');
  SetLength(OutBuf, Cap);
  if Cap = 0 then
    W := nil
  else
    W := @OutBuf[0];

  WriteStr('{ generated by rp_pack / nextpas.core.respack embed toolchain. }'
    + #10 + '{ do not edit; regenerate instead. deterministic output is    }'
    + #10 + '{ locked by the test_respack_embed golden gate.               }'
    + #10);
  WriteStr('const'#10'  ');
  WriteStr(Name);
  WriteStr('_SIZE = ');
  WriteStr(nextpas.core.text.conv.IntToStr(SizeInt(N)));
  WriteStr(';'#10'  ');
  WriteStr(Name);
  WriteStr(': array[0..');
  WriteStr(Name);
  WriteStr('_SIZE - 1] of Byte = ('#10);

  LineCols := 0;
  PData := ABlob.Data;
  // 复用 encoding.hex 单源 + direct PByte stores；inline 零拷贝直通 HEX_UPPER 表，1 MiB 仅一次分配，逐字节无小函数调用
  for I := 0 to SizeInt(N) - 1 do
  begin
    if LineCols = 0 then
    begin
      W^ := Byte(' ');
      Inc(W);
      W^ := Byte(' ');
      Inc(W);
    end;
    B := PData[I];
    W^ := Byte('$');
    Inc(W);
    HexEncodeByteUpper(B, PChar(W));
    Inc(W, 2);
    if I = SizeInt(N) - 1 then
      Break;
    W^ := Byte(',');
    Inc(W);
    Inc(LineCols);
    if LineCols >= PerLine then
    begin
      W^ := Byte(#10);
      Inc(W);
      LineCols := 0;
    end;
  end;
  WriteStr(#10'  );'#10);

  SetLength(OutBuf, SizeInt(W - PByte(@OutBuf[0])));
  Result := OutBuf;
end;

function IdentEqualCI(const AA, AB: string): Boolean; inline;
begin
  // 复用 text.view 零拷贝视图 — bytes.ops SpanEqualIgnoreCase 单源，无手写重复
  Result := TStringView.FromStr(AA).EqualsIgnoreCase(TStringView.FromStr(AB));
end;

function ResPackEmbedIncUnitSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; const AUnitName: string): TBytes;
var
  Body, Head, Tail: TBytes;
  Total: SizeUInt;
  Dst: PByte;
begin
  if not ResPackValidIdent(AUnitName) then
    raise EResPackError.Create('respack.embed: UnitName must be a Pascal ' +
      'identifier ("' + AUnitName + '")');
  if IdentEqualCI(AUnitName, AOpts.ConstName) then
    raise EResPackError.Create('respack.embed: UnitName must differ from ' +
      'ConstName ("' + AUnitName + '")');
  // 阈值前置单源于 respack.limits（同 IncSource，同策略 0 取默认 4MiB，早拒避免三段分配超大临时分配）
  ResPackRequireIncSize(ABlob.Size, ResPackEffectiveIncLimit(AOpts.MaxBlobBytes));
  Body := ResPackEmbedIncSource(ABlob, AOpts);
  Head := StringToBytes('unit ' + AUnitName + ';' + #10 +
    '{$mode objfpc}{$H+}' + #10 + #10 + 'interface' + #10 + #10);
  Tail := StringToBytes(#10 + 'implementation' + #10 + #10 + 'end.' + #10);
  // 通用文本组装单源：与 writer.builder GetMem(Total)+分段 BytesCopy 单源收敛，
  // 单次 SetLength(Total)+分段 BytesCopy inline 零拷贝（bytes.ops 单源，无额外分配），
  // 替代多段二次分配拼接，确定性一致且无双驻留
  Total := SizeUInt(Length(Head)) + SizeUInt(Length(Body)) + SizeUInt(Length(Tail));
  SetLength(Result, Total);
  if Total = 0 then
    Exit;
  Dst := @Result[0];
  if Length(Head) > 0 then
  begin
    BytesCopy(Dst, @Head[0], SizeUInt(Length(Head)));
    Inc(Dst, Length(Head));
  end;
  if Length(Body) > 0 then
  begin
    BytesCopy(Dst, @Body[0], SizeUInt(Length(Body)));
    Inc(Dst, Length(Body));
  end;
  if Length(Tail) > 0 then
    BytesCopy(Dst, @Tail[0], SizeUInt(Length(Tail)));
end;

end.
