program test_tar_contract;
{**
 * @desc tar 源契约：无 FPC RTL 直引、禁 C 运算符、门面纯度、文档/registry 存在性。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes, nextpas.core.test;

var
  Suite: TTestSuite;

const
  C_TAR_UNITS: array[0..7] of string = (
    'src/nextpas.core.tar.pas',
    'src/nextpas.core.tar.base.pas',
    'src/nextpas.core.tar.intf.pas',
    'src/nextpas.core.tar.common.pas',
    'src/nextpas.core.tar.reader.pas',
    'src/nextpas.core.tar.writer.pas',
    'src/nextpas.core.tar.fs.pas',
    'src/nextpas.core.tar.builder.pas'
  );
  C_FORBIDDEN: array[0..9] of string = (
    'sysutils','classes','math','strutils','types','windows','baseunix','unix','dos','sockets'
  );

function ReadText(const P: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try L.LoadFromFile(ExpandFileName('../../../' + P)); Result := L.Text; finally L.Free; end;
end;

function StripComments(const S: string): string;
var I, N: Integer; Br, Pa, Ln: Boolean;
begin
  N := Length(S); SetLength(Result, N); Br:=False; Pa:=False; Ln:=False; I:=1;
  while I <= N do
  begin
    if Br then begin if S[I]='}' then Br:=False else Result[I]:=' '; end
    else if Pa then begin if (S[I]='*') and (I<N) and (S[I+1]=')') then begin Result[I]:=' '; Result[I+1]:=' '; Inc(I); Pa:=False; end else Result[I]:=' '; end
    else if Ln then begin if S[I]=#10 then begin Result[I]:=#10; Ln:=False; end else Result[I]:=' '; end
    else begin if S[I]='{' then begin Result[I]:=' '; Br:=True; end else if (S[I]='(') and (I<N) and (S[I+1]='*') then begin Result[I]:=' '; Result[I+1]:=' '; Inc(I); Pa:=True; end else if (S[I]='/') and (I<N) and (S[I+1]='/') then begin Result[I]:=' '; Result[I+1]:=' '; Inc(I); Ln:=True; end else Result[I]:=S[I]; end;
    Inc(I);
  end;
end;

function IsIdent(Ch: Char): Boolean; inline;
begin Result := Ch in ['a'..'z','A'..'Z','0'..'9','_','.']; end;

function WordAt(const T: string; P: Integer): string;
var E: Integer;
begin E:=P; while (E<=Length(T)) and IsIdent(T[E]) do Inc(E); Result:=Copy(T, P, E-P); end;

procedure CollectUses(const Stripped: string; OutList: TStringList);
var I, N: Integer; LIn: Boolean; W, U: string;
begin
  N:=Length(Stripped); I:=1; LIn:=False;
  while I<=N do
  begin
    if LIn then
    begin
      if Stripped[I]=';' then LIn:=False
      else if not (Stripped[I] in [' ',#9,#10,#13,',']) then
      begin U:=''; while (I<=N) and (Pos(Stripped[I], ',; '#9#10#13)=0) do begin U:=U+LowerCase(Stripped[I]); Inc(I); end; if U<>'' then OutList.Add(U); Continue;
      end;
    end
    else if Stripped[I] in ['u','U'] then
    begin if (I=1) or not IsIdent(Stripped[I-1]) then begin W:=LowerCase(WordAt(Stripped, I)); if W='uses' then begin LIn:=True; Inc(I, Length(W)); Continue; end; end;
    end;
    Inc(I);
  end;
end;

procedure Audit(const Rel: string);
var
  S: string; L: TStringList; I: Integer; Bad, Hit: string;
begin
  S:=StripComments(ReadText(Rel));
  L:=TStringList.Create; try L.Sorted:=True; L.Duplicates:=dupIgnore; CollectUses(S, L); Check(L.Count>0, Rel+': uses found'); Bad:=''; for I:=0 to L.Count-1 do if Pos('nextpas.', L[I])<>1 then Bad:=Bad+L[I]+' '; Check(Bad='', Rel+': uses nextpas.* only (got: '+Trim(Bad)+')'); Hit:=''; for I:=Low(C_FORBIDDEN) to High(C_FORBIDDEN) do if L.IndexOf(C_FORBIDDEN[I])>=0 then Hit:=Hit+C_FORBIDDEN[I]+' '; Check(Hit='', Rel+': no forbidden unit (got: '+Trim(Hit)+')'); finally L.Free; end;
end;

procedure TestNoFpcRtl;
var I: Integer;
begin for I:=Low(C_TAR_UNITS) to High(C_TAR_UNITS) do Audit(C_TAR_UNITS[I]); end;

procedure TestNoCOperators;
var I: Integer; S: string;
begin for I:=Low(C_TAR_UNITS) to High(C_TAR_UNITS) do begin S:=LowerCase(ReadText(C_TAR_UNITS[I])); Check(Pos('+=', S)=0, C_TAR_UNITS[I]+': no +='); Check(Pos('-=', S)=0, C_TAR_UNITS[I]+': no -='); Check(Pos('*=', S)=0, C_TAR_UNITS[I]+': no *='); Check(Pos('/=', S)=0, C_TAR_UNITS[I]+': no /='); Check(Pos('{$coperators', S)=0, C_TAR_UNITS[I]+': no {$COPERATORS}'); end; end;

procedure TestFacadePurity;
var Src, Impl, Low: string;
begin
  Src:=ReadText('src/nextpas.core.tar.pas');
  Impl:=Copy(Src, Pos('implementation', LowerCase(Src)), Length(Src)); Low:=LowerCase(Impl);
  Check(Pos('while ', Low)=0, 'facade no while'); Check(Pos('for ', Low)=0, 'facade no for'); Check(Pos('repeat', Low)=0, 'facade no repeat'); Check(Pos('case ', Low)=0, 'facade no case'); Check(Pos('if ', Low)=0, 'facade no if');
  Check(Pos('TTarReader', Src)>0, 'facade exposes reader'); Check(Pos('TTarWriter', Src)>0, 'facade exposes writer'); Check(Pos('TarPackDir', Src)>0, 'facade exposes fs');
end;

procedure TestDocs;
var C,R,M: string;
begin
  C:=ReadText('docs/tar/CONTRACT.md'); Check(Pos('[INV-1]', C)>0, 'INV-1'); Check(Pos('[INV-5]', C)>0, 'INV-5'); Check(Pos('test_tar_contract', C)>0, 'gate listed'); Check(Pos('IsSafeTarEntryName', C)>0, 'IsSafe documented');
  R:=ReadText('docs/tar/README.md'); Check(Pos('C_TAR_BLOCK_SIZE', R)>0, 'readme block size'); Check(Pos('TarPackDir', R)>0, 'readme fs');
  M:=ReadText('docs/module-registry.md'); Check(Pos('| `tar` |', M)>0, 'registry has tar');
  C:=ReadText('docs/core-module-registry.md'); Check(Pos('| `tar` |', C)>0, 'core registry has tar');
end;

procedure TestCommonInternalBoundary;
var
  Facade, CommonSrc, LowCommon: string;
  SR: TSearchRec;
  BaseDir, FileName, FilePath, Content, Low: string;
  Allowed: TStringList;
  Hit: string;
begin
  // facade must not re-export common (strip comments to avoid false positive from doc comment)
  Facade := LowerCase(StripComments(ReadText('src/nextpas.core.tar.pas')));
  Check(Pos('tar.common', Facade) = 0, 'facade must not uses tar.common (internal kernel not re-exported)');
  // common is internal: comment guard
  CommonSrc := ReadText('src/nextpas.core.tar.common.pas');
  Check(Pos('内部单元', CommonSrc) > 0, 'common marks internal');
  Check(Pos('禁止门面外直引', CommonSrc) > 0, 'common forbids external direct use');
  LowCommon := LowerCase(CommonSrc);
  Check(Pos('design-conventions', LowCommon) > 0, 'common notes design-conventions loop ban');
  // mechanical: any core/src/*.pas outside allowed set must not uses tar.common
  Allowed := TStringList.Create;
  try
    Allowed.Sorted := True;
    Allowed.Duplicates := dupIgnore;
    Allowed.Add('nextpas.core.tar.common.pas');
    Allowed.Add('nextpas.core.tar.reader.pas');
    Allowed.Add('nextpas.core.tar.writer.pas');
    Allowed.Add('nextpas.core.tar.fs.pas');
    BaseDir := ExpandFileName('../../../core/src');
    if FindFirst(BaseDir + PathDelim + 'nextpas.core.*.pas', faAnyFile, SR) = 0 then
    try
      repeat
        FileName := SR.Name;
        if Allowed.IndexOf(LowerCase(FileName)) >= 0 then Continue;
        // skip tar units already allowed, check rest
        FilePath := BaseDir + PathDelim + FileName;
        Content := '';
        try
          with TStringList.Create do try LoadFromFile(FilePath); Content := Text; finally Free; end;
        except Content := ''; end;
        Low := LowerCase(StripComments(Content));
        Hit := '';
        if Pos('nextpas.core.tar.common', Low) > 0 then Hit := FileName;
        Check(Hit = '', 'external direct use of tar.common forbidden (found in ' + Hit + ')');
      until FindNext(SR) <> 0;
    finally FindClose(SR); end;
  finally Allowed.Free; end;
end;

procedure TestCommonNoInlineLoops;
var
  S, Low: string;
begin
  S := ReadText('src/nextpas.core.tar.common.pas');
  Low := LowerCase(S);
  // design-conventions red line 2: real loop bodies must not be inline (avoid I-Cache bloat)
  // 6 hot paths with 512/variable loops must stay out-of-line
  Check(Pos('tarcomputechecksumunsigned', Low) > 0, 'common has checksum unsigned');
  Check(Pos('tarcomputechecksumunsigned(ab', Low) > 0, 'sig present');
  // forbid inline on those declarations (interface and implementation)
  Check(Pos('function tarcomputechecksumunsigned(ab', Low) > 0, 'decl present');
  // mechanical: ensure no "tarcomputechecksumunsigned...; inline" remains
  Check(Pos('tarcomputechecksumunsigned(ab', Low) > 0, 'check');
  // scan lines: if declaration line contains inline -> fail
  // simplified: the file must not contain the old inline forms for loop bodies
  Check(Pos('tarcomputechecksumunsigned(ablock: pbyte): int64; inline', Low) = 0, 'TarComputeChecksumUnsigned must not be inline');
  Check(Pos('tarcomputechecksumsigned(ablock: pbyte): int64; inline', Low) = 0, 'TarComputeChecksumSigned must not be inline');
  Check(Pos('tarheaderiszeroblock(ablock: pbyte): boolean; inline', Low) = 0, 'TarHeaderIsZeroBlock must not be inline');
  Check(Pos('tarheaderiszeroorvalid(ablock: pbyte; apos: sizeuint): boolean; inline', Low) = 0, 'TarHeaderIsZeroOrValid must not be inline');
  Check(Pos('tarparsenumericfield(abase: pbyte; alen: sizeuint; apos: sizeuint): int64; inline', Low) = 0, 'TarParseNumericField must not be inline');
  Check(Pos('tarformatnumericfield(ablock: pbyte; aoff, alen: sizeuint; avalue: int64); inline', Low) = 0, 'TarFormatNumericField must not be inline');
  // implementation side also must be out-of-line (no inline after header)
  Check(Pos('function tarcomputechecksumsigned(ablock: pbyte): int64; inline', Low) = 0, 'impl TarComputeChecksumSigned not inline');
  Check(Pos('function tarheaderiszeroblock(ablock: pbyte): boolean; inline', Low) = 0, 'impl TarHeaderIsZeroBlock not inline');
  Check(Pos('function tarheaderiszeroorvalid(ablock: pbyte; apos: sizeuint): boolean; inline', Low) = 0, 'impl TarHeaderIsZeroOrValid not inline');
  Check(Pos('function tarparsenumericfield(abase: pbyte; alen: sizeuint; apos: sizeuint): int64; inline', Low) = 0, 'impl TarParseNumericField not inline');
  Check(Pos('procedure tarformatnumericfield(ablock: pbyte; aoff, alen: sizeuint; avalue: int64); inline', Low) = 0, 'impl TarFormatNumericField not inline');
  // thin guards remain inline (allowed); Move[AValue[1]] patterns must not be inline per red line 1
  Check(Pos('function tarpadtoblock(asize: int64): int64; inline', Low) > 0, 'TarPadToBlock stays inline (thin)');
  Check(Pos('function tarstoredchecksum(ablock: pbyte): int64; inline', Low) > 0, 'TarStoredChecksum stays inline (thin forward)');
  Check(Pos('procedure tarputheaderstring(ablock: pbyte; aoff, alen: sizeuint; const avalue: string); inline', Low) = 0, 'TarPutHeaderString must not be inline (Move[AValue[1]] ban)');
end;

procedure TestReaderSinglePass;
var
  S, Low: string;
begin
  S := ReadText('src/nextpas.core.tar.reader.pas');
  Low := LowerCase(S);
  // 单遍512融合：FieldSlice 经不透明缓存单次 ScanNulFieldTruncations，接口不暴露七字段扁平化 TTarScanCache
  Check(Pos('ttarscancache', Low) = 0, 'reader must not expose TTarScanCache flat 7-field cache in interface');
  Check(Pos('scannulfieldtruncations', Low) > 0, 'reader uses ScanNulFieldTruncations single-source single-pass 512B');
  Check((Pos('fscanvalid', Low) > 0) and (Pos('fscanpos', Low) > 0) and (Pos('fscanlens', Low) > 0), 'reader has opaque FScanValid/FScanPos/FScanLens generic cache');
  Check(Pos('c_tar_layout', Low) > 0, 'reader references tar layout single source');
  Check(Pos('lcached', Low) > 0, 'FieldSlice uses LCached fusion dispatch');
  // EnsureHeaderScanned 融合实现细节已下沉为实现侧 CacheHeader，不在接口暴露
  Check(Pos('procedure ensureheaderscanned', Low) = 0, 'EnsureHeaderScanned must not be exposed as class method');
  Check(Pos('cacheheader', Low) > 0, 'impl uses CacheHeader opaque helper');
end;

procedure TestReaderInlineGate;
var
  S, Low: string;
begin
  S := ReadText('src/nextpas.core.tar.reader.pas');
  Low := LowerCase(S);
  // design-conventions 红线1 机械门禁：含 Move/CompareMem 且喂 [1]/PAnsiChar 的函数禁 inline（FPC 3.3.1 常量传播拷栈垃圾）
  // StringField / SliceToString 含 SpanToString(Move Result[1])，必须外联
  Check(Pos('function stringfield(aofs', Low) > 0, 'reader has StringField');
  Check(Pos('function stringfield(aofs, alen: sizeuint): string; inline', Low) = 0, 'StringField must not be inline (Move Result[1] red line1)');
  Check(Pos('function slicetostring(abase: pbyte; alen: sizeuint): string; inline', Low) = 0, 'SliceToString must not be inline (Move Result[1] red line1)');
  Check(Pos('function cachedfield(aofs, alen: sizeuint; var acached: string): string; inline', Low) = 0, 'CachedField must not be inline (CompareMem @ACached[1] red line1)');
  Check(Pos('function combineprefixname(const aprefix, aname: tbytespan): string; inline', Low) = 0, 'CombinePrefixName must not be inline (Result[1] double feed)');
  // 已移除 EntryData deprecated 拷贝（401 vs 201 allocs 翻倍），热路径零拷贝 TrySlice；EntryDataOfs/EntryDataSlice 为合法薄转发，需精确匹配 ': tbytes' 避免前缀误命中
  Check(Pos('function entrydata:', Low) = 0, 'EntryData removed, use TrySlice/EntryDataSlice zero-copy');
  Check(Pos('function entrydata(', Low) = 0, 'EntryData removed, use TrySlice/EntryDataSlice zero-copy');
  // 薄转发安全者保持 inline
  Check(Pos('function magichasustar: boolean; inline', Low) > 0, 'MagicHasUStar stays inline (safe thin)');
  Check(Pos('procedure clearglobalpax; inline', Low) > 0, 'ClearGlobalPax stays inline (safe)');
  Check(Pos('function tryslice(out aslice: tbytespan): boolean; inline', Low) > 0, 'TrySlice stays inline (safe zero-copy view)');
  // 实现侧亦禁 inline（含 Move）
  Check(Pos('function ttarreader.stringfield(aofs, alen: sizeuint): string; inline', Low) = 0, 'impl StringField not inline');
  Check(Pos('function ttarreader.slicetostring(abase: pbyte; alen: sizeuint): string; inline', Low) = 0, 'impl SliceToString not inline');
end;

procedure TestPaxGlobalIsolation;
var
  S, Low: string;
begin
  S := ReadText('src/nextpas.core.tar.reader.pas');
  Low := LowerCase(S);
  // pax g 全局持久需 guard 作用域，无 guard 单次消费自动清理防跨条目/跨镜像污染
  Check(Pos('acquireglobalpaxguard', Low) > 0, 'reader has AcquireGlobalPaxGuard RAII');
  Check(Pos('clearglobalpax', Low) > 0, 'reader has ClearGlobalPax');
  Check(Pos('fglobalpaxpath', Low) > 0, 'reader has FGlobalPaxPath guard state');
  Check(Pos('length(fguards) = 0', Low) > 0, 'reader auto-clears global when no guard (single-use)');
  Check(Pos('fglobalpaxpath := ''''', Low) > 0, 'auto-clear assigns empty to prevent pollution');
end;

begin
  Suite:=TTestSuite.Create('tar.contract');
  Suite.Test('no fpc rtl', @TestNoFpcRtl);
  Suite.Test('no coperators', @TestNoCOperators);
  Suite.Test('facade purity', @TestFacadePurity);
  Suite.Test('docs', @TestDocs);
  Suite.Test('common internal boundary', @TestCommonInternalBoundary);
  Suite.Test('common no inline loops', @TestCommonNoInlineLoops);
  Suite.Test('reader single pass header scan', @TestReaderSinglePass);
  Suite.Test('reader inline redline gate', @TestReaderInlineGate);
  Suite.Test('pax global isolation', @TestPaxGlobalIsolation);
  if not Suite.Run then Halt(1);
end.
