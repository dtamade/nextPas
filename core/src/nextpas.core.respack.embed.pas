unit nextpas.core.respack.embed;

{** @desc 嵌入工具链：blob → .inc typed const（确定性，golden 锁定），纯内存，阈值单源 embed.limits（4MiB）。 }

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

{ 阈值兼容别名单源于 respack.limits（→ embed.limits EMBED_*），此处不重定义 }
function ResPackDefaultEmbedOptions: TResPackEmbedOptions; inline;
function ResPackDefaultIncOptions: TResPackIncOptions;

{ ASCII Pascal 标识符判定：首字符字母/下划线，其余字母/数字/下划线 }
function ResPackValidIdent(const AName: string): Boolean;

{ 嵌入映射选项校验（embed 拥有）：Strip/AddPrefix 斜杠规则 + 空 glob 拒绝；
  纯内存无 FS，dirsource seam 进入 Walk 前调用，不 inline（loop 守红线2）。 }
procedure ResPackEmbedCheckOptions(const AOpts: TResPackEmbedOptions);

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
  Result.BytesPerLine := nextpas.core.respack.limits.RESPACK_INC_DEFAULT_BYTES_PER_LINE;
  Result.MaxBlobBytes := nextpas.core.respack.limits.RESPACK_INC_MAX_BLOB_BYTES;
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

procedure ResPackEmbedCheckOptions(const AOpts: TResPackEmbedOptions);
var
  I: SizeUInt;
begin
  if (AOpts.StripPrefix <> '') and
    ((Length(AOpts.StripPrefix) = 0) or (AOpts.StripPrefix[Length(AOpts.StripPrefix)] <> '/')) then
    raise EResPackError.Create('respack.embed: StripPrefix must be empty or ' +
      'end with "/" ("' + AOpts.StripPrefix + '")');
  if (AOpts.AddPrefix <> '') and
    ((Length(AOpts.AddPrefix) = 0) or (AOpts.AddPrefix[Length(AOpts.AddPrefix)] <> '/')) then
    raise EResPackError.Create('respack.embed: AddPrefix must be empty or ' +
      'end with "/" ("' + AOpts.AddPrefix + '")');
  if SizeUInt(Length(AOpts.IncludeGlobs)) > 0 then
    for I := 0 to SizeUInt(Length(AOpts.IncludeGlobs)) - 1 do
      if Length(AOpts.IncludeGlobs[I]) = 0 then
        raise EResPackError.Create('respack.embed: empty include glob pattern');
  if SizeUInt(Length(AOpts.ExcludeGlobs)) > 0 then
    for I := 0 to SizeUInt(Length(AOpts.ExcludeGlobs)) - 1 do
      if Length(AOpts.ExcludeGlobs[I]) = 0 then
        raise EResPackError.Create('respack.embed: empty exclude glob pattern');
end;

{ Domain overflow guard 单层：Try* 单源于 base.utils（owner），inline 零拷贝，
  固定串收口为常量，消除 Checked/Cap 双层无约束转发 }
const
  EMBED_CAP_OVERFLOW_MSG = 'respack.embed: capacity overflow';

{ WriteStr 单源：BytesCopy 单 Move，EmitIncContent/IncUnit 复用，inline 热路径 }
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

{ Inc 直写单源：header+body+尾零拷贝，Hex 4-wide 单源，外联守 I-Cache }
procedure EmitIncContent(var AW: PByte; const ABlob: TResPackBlob; const AName, ANStr: string; const APerLine: Integer; const AN: SizeUInt);
var
  I: SizeInt;
  LineCols: Integer;
  PData: PByte;

begin
  WriteStrTo(AW, '{ generated by rp_pack / nextpas.core.respack embed toolchain. }' + #10);
  WriteStrTo(AW, '{ do not edit; regenerate instead. deterministic output is    }' + #10);
  WriteStrTo(AW, '{ locked by the test_respack_embed golden gate.               }' + #10);
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

{ Not inline: FPC trunk -O2 REGVAR keeps a stale register for Cap across the
  inline TryAddSizeUInt var-param chain; stale 0 yields empty buffer and nil
  write cursor. Called once per file, call cost negligible. }
function CalcIncCapacity(const AName, ANStr: string; const APerLine: Integer; const AN: SizeUInt): SizeUInt;
var
  Cap, BodyLen, LTmp, Lines: SizeUInt;
begin
  { Try* 单源于 base.utils owner（inline），直调加域异常，无 Checked 中转 }
  Cap := 0;
  if not TryAddSizeUInt(Cap, SizeUInt(Length('{ generated by rp_pack / nextpas.core.respack embed toolchain. }' + #10 + '{ do not edit; regenerate instead. deterministic output is    }' + #10 + '{ locked by the test_respack_embed golden gate.               }' + #10)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length('const'#10'  ')), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(AName)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length('_SIZE = ')), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(ANStr)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(';'#10'  ')), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(AName)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(': array[0..')), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(AName)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length('_SIZE - 1] of Byte = ('#10)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  Lines := AN div SizeUInt(APerLine);
  if AN mod SizeUInt(APerLine) <> 0 then
    Inc(Lines);
  if not TryMulSizeUInt(AN, 4, BodyLen) then
    raise EResPackTooLarge.Create('respack.embed: blob too large');
  if Lines > 1 then
  begin
    if not TryMulSizeUInt(Lines - 1, 3, LTmp) then
      raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
    if not TryAddSizeUInt(BodyLen, LTmp, BodyLen) then
      raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  end;
  if not TryAddSizeUInt(BodyLen, 1, BodyLen) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, BodyLen, Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Cap, SizeUInt(Length(#10'  );'#10)), Cap) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  Result := Cap;
end;

{ Inc 共通前检单源：ConstName 判定＋空包校验＋阈值前检＋容量预计算，
  IncSource/IncUnitSource 共用，消除两处重复；非 inline（一次调用，守 I-Cache） }
procedure PrepareIncParams(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; out AName, ANStr: string;
  out APerLine: Integer; out AN, ACapInc: SizeUInt);
begin
  AName := AOpts.ConstName;
  if not ResPackValidIdent(AName) then
    raise EResPackError.Create('respack.embed: ConstName must be a Pascal ' +
      'identifier ("' + AName + '")');
  if ABlob.Data = nil then
    raise EResPackError.Create('respack.embed: blob is nil');
  if ABlob.Size = 0 then
    raise EResPackError.Create('respack.embed: blob is empty');
  APerLine := AOpts.BytesPerLine;
  if APerLine <= 0 then
    APerLine := nextpas.core.respack.limits.RESPACK_INC_DEFAULT_BYTES_PER_LINE;
  AN := ABlob.Size;
  ResPackRequireIncSize(AN, ResPackEffectiveIncLimit(AOpts.MaxBlobBytes));
  ANStr := nextpas.core.text.conv.IntToStr(SizeInt(AN));
  ACapInc := CalcIncCapacity(AName, ANStr, APerLine, AN);
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
  { 共通前检＋容量预计算单源于 PrepareIncParams（inline 零拷贝阈值，单次精确 SetLength） }
  PrepareIncParams(ABlob, AOpts, Name, NStr, PerLine, N, Cap);
  SetLength(OutBuf, Cap);
  if Cap = 0 then
    W := nil
  else
    W := @OutBuf[0];
  Start := W;
  EmitIncContent(W, ABlob, Name, NStr, PerLine, N);
  if SizeUInt(W - Start) <> Cap then
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
  // UnitName 私有校验＋共通前检单源于 PrepareIncParams（与 IncSource 同阈值/空包/容量路径）
  PrepareIncParams(ABlob, AOpts, Name, NStr, PerLine, N, CapInc);
  Total := 0;
  if not TryAddSizeUInt(Total, SizeUInt(Length('unit ')), Total) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Total, SizeUInt(Length(AUnitName)), Total) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Total, SizeUInt(Length(';' + #10 + '{$mode objfpc}{$H+}' + #10 + #10 + 'interface' + #10 + #10)), Total) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Total, CapInc, Total) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
  if not TryAddSizeUInt(Total, SizeUInt(Length(#10 + 'implementation' + #10 + #10 + 'end.' + #10)), Total) then
    raise EResPackTooLarge.Create(EMBED_CAP_OVERFLOW_MSG);
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
