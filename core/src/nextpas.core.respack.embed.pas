unit nextpas.core.respack.embed;

{** @desc 嵌入工具链库（S4）：blob → .inc typed const 源文本。格式逻辑全部收口 core 侧，
  CLI（core/tools/respack）只是薄壳。本单元仅依赖 L1 text.strings/text.char/
  text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、零文件系统依赖，PChar 零拷贝
  视图 + inline 热路径）+ embed.limits 阈值策略独立模块单源（4MiB 策略集中、可配置 MaxBlobBytes、
  前置拒绝单源 EmbedRequireIncSize/ResPackRequireIncSize inline 零拷贝，已从 respack.limits 抽取为
  L1 独立策略模块 nextpas.core.embed.limits 供其他嵌入载体复用，respack.limits 为兼容转发）
  + bytes.ops 单源（WriteStrTo 单源 inline 零拷贝：BytesCopy 单 Move + PAnsiChar 零拷贝视图，EmitIncContent/IncUnit 共用，IncUnit 单次 SetLength+分段 BytesCopy 与
  writer.builder GetMem(Total)单源收敛，通用文本组装单源，替代二次分配拼接），纯内存可复用（零 FS/零 writer/
  零 dirsource 依赖，目录 → 过滤/映射 → 打包 blob 的 IO 管线收口于
  respack.dirsource（L2 FS 缝），唯一 L2→L2 FS seam）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.embed.limits,
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
    MaxBlobBytes: SizeUInt; { 0=默认 4MiB；显式可覆盖，策略单源于 embed.limits 独立模块 }
  end;

const
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES; { 兼容别名，单源于 embed.limits EMBED_* 规范，消除 RESPACK->RESPACK 二重转发冗余；经验阈值 <4MiB 走 .inc }

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

{ capacity helpers — single-source fixed overflow message, inline zero-copy, 消除 14 次重复字符串行噪，复用 Checked* 单源 }
procedure CapAdd(var ACap: SizeUInt; const ADelta: SizeUInt); inline;
begin
  CheckedAdd(ACap, ADelta, 'respack.embed: capacity overflow');
end;

procedure CapMul(const ALeft, ARight: SizeUInt; var ARes: SizeUInt); inline;
begin
  CheckedMul(ALeft, ARight, ARes, 'respack.embed: capacity overflow');
end;

{ WriteStr 单源：PByte 游标追加 string，bytes.ops.BytesCopy inline 单 Move 零拷贝（PAnsiChar 视图无分配），外层 EmitIncContent/IncUnit 均复用；消除 EmitIncContent 与 ResPackEmbedIncUnitSource 内同名闭包重复，inline 守热路径 }
procedure WriteStrTo(var ADst: PByte; const S: string); inline;
var
  L: SizeInt;
begin
  L := Length(S);
  if L = 0 then
    Exit;
  BytesCopy(ADst, PAnsiChar(S), SizeUInt(L));
  Inc(ADst, L);
end;

{ Inc 内容直写单源：header+声明+body+尾零拷贝写入，bytes.ops.BytesCopy inline 单 Move，HexEncodeDollarCommaBulkUpper 4-wide 单源，外联守 I-Cache（外层不 inline 避热点复制膨胀，内层 WriteStrTo/BytesCopy inline），writer.builder 单源收敛；供 IncSource/IncUnit 单次 SetLength 直写复用，消除 4MiB 内二次整包拷贝 }
procedure EmitIncContent(var AW: PByte; const ABlob: TResPackBlob; const AName, ANStr: string; const APerLine: Integer; const AN: SizeUInt);
var
  I: SizeInt;
  LineCols: Integer;
  PData: PByte;

begin
  WriteStrTo(AW, '{ generated by rp_pack / nextpas.core.respack embed toolchain. }'
    + #10 + '{ do not edit; regenerate instead. deterministic output is    }'
    + #10 + '{ locked by the test_respack_embed golden gate.               }'
    + #10);
  WriteStrTo(AW, 'const'#10'  ');
  WriteStrTo(AW, AName);
  WriteStrTo(AW, '_SIZE = ');
  WriteStrTo(AW, ANStr);
  WriteStrTo(AW, ';'#10'  ');
  WriteStrTo(AW, AName);
  WriteStrTo(AW, ': array[0..');
  WriteStrTo(AW, AName);
  WriteStrTo(AW, '_SIZE - 1] of Byte = ('#10);
  LineCols := 0;
  PData := ABlob.Data;
  I := 0;
  while I < SizeInt(AN) do
  begin
    if LineCols = 0 then
    begin
      AW^ := Byte(' ');
      Inc(AW);
      AW^ := Byte(' ');
      Inc(AW);
    end;
    if SizeInt(AN) - I <= APerLine - LineCols then
    begin
      if SizeInt(AN) - I = 1 then
      begin
        AW^ := Byte('$');
        Inc(AW);
        HexEncodeByteUpper(PData[I], PChar(AW));
        Inc(AW, 2);
      end
      else
      begin
        HexEncodeDollarCommaBulkUpper(@PData[I], SizeUInt(SizeInt(AN) - I - 1), AW);
        Inc(AW, (SizeInt(AN) - I - 1) * 4);
        AW^ := Byte('$');
        Inc(AW);
        HexEncodeByteUpper(PData[SizeInt(AN) - 1], PChar(AW));
        Inc(AW, 2);
      end;
      Break;
    end
    else
    begin
      HexEncodeDollarCommaBulkUpper(@PData[I], SizeUInt(APerLine - LineCols), AW);
      Inc(AW, (APerLine - LineCols) * 4);
      Inc(I, APerLine - LineCols);
      AW^ := Byte(#10);
      Inc(AW);
      LineCols := 0;
    end;
  end;
  WriteStrTo(AW, #10'  );'#10);
end;

function CalcIncCapacity(const AName, ANStr: string; const APerLine: Integer; const AN: SizeUInt): SizeUInt; inline;
var
  Cap, BodyLen, LTmp, Lines: SizeUInt;
begin
  Cap := 0;
  CapAdd(Cap, SizeUInt(Length('{ generated by rp_pack / nextpas.core.respack embed toolchain. }' + #10 + '{ do not edit; regenerate instead. deterministic output is    }' + #10 + '{ locked by the test_respack_embed golden gate.               }' + #10)));
  CapAdd(Cap, SizeUInt(Length('const'#10'  ')));
  CapAdd(Cap, SizeUInt(Length(AName)));
  CapAdd(Cap, SizeUInt(Length('_SIZE = ')));
  CapAdd(Cap, SizeUInt(Length(ANStr)));
  CapAdd(Cap, SizeUInt(Length(';'#10'  ')));
  CapAdd(Cap, SizeUInt(Length(AName)));
  CapAdd(Cap, SizeUInt(Length(': array[0..')));
  CapAdd(Cap, SizeUInt(Length(AName)));
  CapAdd(Cap, SizeUInt(Length('_SIZE - 1] of Byte = ('#10)));
  Lines := AN div SizeUInt(APerLine);
  if AN mod SizeUInt(APerLine) <> 0 then
    Inc(Lines);
  CheckedMul(AN, 4, BodyLen, 'respack.embed: blob too large');
  if Lines > 1 then
  begin
    CapMul(Lines - 1, 3, LTmp);
    CapAdd(BodyLen, LTmp);
  end;
  CapAdd(BodyLen, 1);
  CapAdd(Cap, BodyLen);
  CapAdd(Cap, SizeUInt(Length(#10'  );'#10)));
  Result := Cap;
end;

function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes;
var
  Name: string;
  NStr: string;
  PerLine: Integer;
  N: SizeUInt;
  Cap: SizeUInt;
  OutBuf: TBytes;
  W, Start: PByte;
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
  { 容量精确预计算 — CapAdd/CapMul 单源固定 overflow 消息，inline 零拷贝，消除 14 次重复字符串行噪；BytesCopy 单源 }
  N := ABlob.Size;
  // 阈值前置拒绝单源于 embed.limits 独立模块（inline 零拷贝，0 零值取默认 4MiB，避免两处硬编码重复与超大临时分配）
  ResPackRequireIncSize(N, ResPackEffectiveIncLimit(AOpts.MaxBlobBytes));
  NStr := nextpas.core.text.conv.IntToStr(SizeInt(N));
  Cap := CalcIncCapacity(Name, NStr, PerLine, N);
  SetLength(OutBuf, Cap);
  if Cap = 0 then
    W := nil
  else
    W := @OutBuf[0];
  Start := W;
  EmitIncContent(W, ABlob, Name, NStr, PerLine, N);
  SetLength(OutBuf, SizeInt(W - Start));
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
  Name, NStr: string;
  PerLine: Integer;
  N: SizeUInt;
  CapInc, Total: SizeUInt;
  Dst, Start: PByte;

begin
  if not ResPackValidIdent(AUnitName) then
    raise EResPackError.Create('respack.embed: UnitName must be a Pascal ' +
      'identifier ("' + AUnitName + '")');
  if IdentEqualCI(AUnitName, AOpts.ConstName) then
    raise EResPackError.Create('respack.embed: UnitName must differ from ' +
      'ConstName ("' + AUnitName + '")');
  // 阈值前置单源于 embed.limits 独立模块（同 IncSource，同策略 0 取默认 4MiB，早拒避免三段分配超大临时分配）— 单源 ResPackEffectiveIncLimit/ResPackRequireIncSize，零拷贝 inline，与 IncSource 同阈值路径
  PerLine := AOpts.BytesPerLine;
  if PerLine <= 0 then
    PerLine := RESPACK_INC_DEFAULT_BYTES_PER_LINE;
  N := ABlob.Size;
  ResPackRequireIncSize(N, ResPackEffectiveIncLimit(AOpts.MaxBlobBytes));
  if not ResPackValidIdent(AOpts.ConstName) then
    raise EResPackError.Create('respack.embed: ConstName must be a Pascal ' +
      'identifier ("' + AOpts.ConstName + '")');
  if ABlob.Data = nil then
    raise EResPackError.Create('respack.embed: blob is nil');
  if ABlob.Size = 0 then
    raise EResPackError.Create('respack.embed: blob is empty');
  Name := AOpts.ConstName;
  NStr := nextpas.core.text.conv.IntToStr(SizeInt(N));
  CapInc := CalcIncCapacity(Name, NStr, PerLine, N);
  Total := 0;
  CapAdd(Total, SizeUInt(Length('unit ')));
  CapAdd(Total, SizeUInt(Length(AUnitName)));
  CapAdd(Total, SizeUInt(Length(';' + #10 + '{$mode objfpc}{$H+}' + #10 + #10 + 'interface' + #10 + #10)));
  CapAdd(Total, CapInc);
  CapAdd(Total, SizeUInt(Length(#10 + 'implementation' + #10 + #10 + 'end.' + #10)));
  SetLength(Result, Total);
  if Total = 0 then
    Exit;
  Dst := @Result[0];
  Start := Dst;
  WriteStrTo(Dst, 'unit ');
  WriteStrTo(Dst, AUnitName);
  WriteStrTo(Dst, ';' + #10 + '{$mode objfpc}{$H+}' + #10 + #10 + 'interface' + #10 + #10);
  EmitIncContent(Dst, ABlob, Name, NStr, PerLine, N); // 单次 SetLength 后直写，bytes.ops/hex 单源 inline 零拷贝，消除 4MiB 内二次整包 BytesCopy
  WriteStrTo(Dst, #10 + 'implementation' + #10 + #10 + 'end.' + #10);
  if SizeUInt(Dst - Start) <> Total then
    SetLength(Result, SizeInt(Dst - Start));
end;

end.
