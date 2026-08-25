program test_zip_contract;
{**
 * @desc zip 模块源契约门：把项目规范编码为 CI 机械断言。
 *
 * 1. 无 FPC RTL 直接依赖：生产单元（src/nextpas.core.zip*.pas）的 uses
 *    子句只允许 nextpas.* 单元——FPC RTL 与第三方库经 owner 模块间接使用。
 *    这是"不准直接依赖引用 fpc 的 rtl"规范在本模块的执行点。
 * 2. 禁用 C 风格复合赋值与 {$COPERATORS} 指令。
 * 3. 门面纯度：nextpas.core.zip.pas 只做 re-export/inline 委托，无控制流。
 * 4. 文档契约：CONTRACT.md 不变量编号、README 关键词、registry 注册行、
 *    示例工程存在性。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.test;

var
  T: TTestSuite;

const
  C_ZIP_UNITS: array[0..4] of string = (
    'src/nextpas.core.zip.pas',
    'src/nextpas.core.zip.base.pas',
    'src/nextpas.core.zip.writer.pas',
    'src/nextpas.core.zip.reader.pas',
    'src/nextpas.core.zip.fs.pas'
  );

  { 经典 RTL / 平台单元黑名单：与"只允许 nextpas.*"白名单互为双保险 }
  C_FORBIDDEN_UNITS: array[0..14] of string = (
    'sysutils', 'classes', 'math', 'dateutils', 'strutils',
    'types', 'windows', 'baseunix', 'unix', 'ctypes',
    'cmem', 'zlib', 'dos', 'linux', 'sockets'
  );

function ReadText(const ARelativePath: string): string;
var
  LPath: string;
  LLines: TStringList;
begin
  LPath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LPath), 'source file exists: ' + LPath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LPath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

{ 去除 Pascal 注释（brace / paren-star / 行注释），避免注释内容干扰解析 }
function StripPascalComments(const ASource: string): string;
var
  I, LLen: Integer;
  LInBrace, LInParen, LInLine: Boolean;
begin
  LLen := Length(ASource);
  SetLength(Result, LLen);
  LInBrace := False;
  LInParen := False;
  LInLine := False;
  I := 1;
  while I <= LLen do
  begin
    if LInBrace then
    begin
      if ASource[I] = '}' then
        LInBrace := False
      else
        Result[I] := ' ';
    end
    else if LInParen then
    begin
      if (ASource[I] = '*') and (I < LLen) and (ASource[I + 1] = ')') then
      begin
        Result[I] := ' ';
        Result[I + 1] := ' ';
        Inc(I);
        LInParen := False;
      end
      else
        Result[I] := ' ';
    end
    else if LInLine then
    begin
      if ASource[I] = #10 then
      begin
        Result[I] := #10;
        LInLine := False;
      end
      else
        Result[I] := ' ';
    end
    else
    begin
      if ASource[I] = '{' then
      begin
        Result[I] := ' ';
        LInBrace := True;
      end
      else if (ASource[I] = '(') and (I < LLen) and (ASource[I + 1] = '*') then
      begin
        Result[I] := ' ';
        Result[I + 1] := ' ';
        Inc(I);
        LInParen := True;
      end
      else if (ASource[I] = '/') and (I < LLen) and (ASource[I + 1] = '/') then
      begin
        Result[I] := ' ';
        Result[I + 1] := ' ';
        Inc(I);
        LInLine := True;
      end
      else
        Result[I] := ASource[I];
    end;
    Inc(I);
  end;
end;

function IsIdentChar(ACh: Char): Boolean; inline;
begin
  Result := ACh in ['a'..'z', 'A'..'Z', '0'..'9', '_', '.'];
end;

function WordAt(const AText: string; APos: Integer): string;
var
  LE: Integer;
begin
  LE := APos;
  while (LE <= Length(AText)) and IsIdentChar(AText[LE]) do
    Inc(LE);
  Result := Copy(AText, APos, LE - APos);
end;

{ 收集全部 uses 子句中的单元名（小写）。interface 与 implementation 的依赖
  都在审计范围内。 }
procedure CollectUsedUnits(const AStrippedSource: string; AOut: TStringList);
var
  I, LLen: Integer;
  LW, LUnit: string;
  LInUses: Boolean;
begin
  LLen := Length(AStrippedSource);
  I := 1;
  LInUses := False;
  while I <= LLen do
  begin
    if LInUses then
    begin
      if AStrippedSource[I] = ';' then
        LInUses := False
      else if not (AStrippedSource[I] in [' ', #9, #10, #13, ',']) then
      begin
        LUnit := '';
        while (I <= LLen) and (Pos(AStrippedSource[I], ',; '#9#10#13) = 0) do
        begin
          LUnit := LUnit + LowerCase(AStrippedSource[I]);
          Inc(I);
        end;
        if LUnit <> '' then
          AOut.Add(LUnit);
        Continue;
      end;
    end
    else if AStrippedSource[I] in ['u', 'U'] then
    begin
      if (I = 1) or not IsIdentChar(AStrippedSource[I - 1]) then
      begin
        LW := LowerCase(WordAt(AStrippedSource, I));
        if LW = 'uses' then
        begin
          LInUses := True;
          Inc(I, Length(LW));
          Continue;
        end;
      end;
    end;
    Inc(I);
  end;
end;

procedure AuditOneUnit(const ARelPath: string);
var
  LStripped: string;
  LUnits: TStringList;
  LI: Integer;
  LBad, LForbiddenHit: string;
begin
  LStripped := StripPascalComments(ReadText(ARelPath));
  LUnits := TStringList.Create;
  try
    LUnits.Sorted := True;
    LUnits.Duplicates := dupIgnore;
    CollectUsedUnits(LStripped, LUnits);
    Check(LUnits.Count > 0, ARelPath + ': uses clauses found');
    LBad := '';
    for LI := 0 to LUnits.Count - 1 do
      if Pos('nextpas.', LUnits[LI]) <> 1 then
        LBad := LBad + LUnits[LI] + ' ';
    Check(LBad = '', ARelPath + ': every used unit is nextpas.* (got: ' +
      Trim(LBad) + ')');
    LForbiddenHit := '';
    for LI := Low(C_FORBIDDEN_UNITS) to High(C_FORBIDDEN_UNITS) do
      if LUnits.IndexOf(C_FORBIDDEN_UNITS[LI]) >= 0 then
        LForbiddenHit := LForbiddenHit + C_FORBIDDEN_UNITS[LI] + ' ';
    Check(LForbiddenHit = '', ARelPath + ': no classic-RTL unit used (got: ' +
      Trim(LForbiddenHit) + ')');
  finally
    LUnits.Free;
  end;
end;

procedure TestNoFpcRtlDependencies;
var
  LI: Integer;
begin
  for LI := Low(C_ZIP_UNITS) to High(C_ZIP_UNITS) do
    AuditOneUnit(C_ZIP_UNITS[LI]);
end;

procedure TestNoCStyleOperators;
var
  LI: Integer;
  LRel, LLower: string;
begin
  for LI := Low(C_ZIP_UNITS) to High(C_ZIP_UNITS) do
  begin
    LRel := C_ZIP_UNITS[LI];
    LLower := LowerCase(ReadText(LRel));
    Check(Pos('+=', LLower) = 0, LRel + ': no += operator');
    Check(Pos('-=', LLower) = 0, LRel + ': no -= operator');
    Check(Pos('*=', LLower) = 0, LRel + ': no *= operator');
    Check(Pos('/=', LLower) = 0, LRel + ': no /= operator');
    Check(Pos('{$coperators', LLower) = 0,
      LRel + ': no {$COPERATORS} directive');
  end;
end;

procedure TestFacadePurity;
var
  LSource, LImplSlice, LLower: string;
begin
  LSource := ReadText('src/nextpas.core.zip.pas');
  LImplSlice := Copy(LSource, Pos('implementation', LowerCase(LSource)),
    Length(LSource));
  LLower := LowerCase(LImplSlice);
  { 门面只允许 inline 委托：实现段不得含控制流或分支逻辑 }
  Check(Pos('while ', LLower) = 0, 'facade impl: no while loops');
  Check(Pos('for ', LLower) = 0, 'facade impl: no for loops');
  Check(Pos('repeat', LLower) = 0, 'facade impl: no repeat loops');
  Check(Pos('case ', LLower) = 0, 'facade impl: no case dispatch');
  Check(Pos('if ', LLower) = 0, 'facade impl: no conditionals');
  { 关键 re-export 面必须在场 }
  Check(Pos('TZipAddOptions', LSource) > 0,
    'facade exposes add options type');
  Check(Pos('TZipExtractOptions', LSource) > 0,
    'facade exposes extract options type');
  Check(Pos('DefaultZipAddOptions', LSource) > 0,
    'facade re-exports add options default');
  Check(Pos('ZipExtractToDirWithOptions', LSource) > 0,
    'facade re-exports extract-with-options entry point');
end;

procedure TestDocsContract;
var
  LContract, LReadme, LRegistry: string;
begin
  LContract := ReadText('docs/zip/CONTRACT.md');
  Check(Pos('[INV-7]', LContract) > 0, 'contract has INV-7 (descriptor)');
  Check(Pos('[INV-8]', LContract) > 0, 'contract has INV-8 (size hint)');
  Check(Pos('[INV-9]', LContract) > 0, 'contract has INV-9 (dir finalize)');
  Check(Pos('[INV-10]', LContract) > 0, 'contract has INV-10 (symlinks)');
  Check(Pos('test_zip_contract', LContract) > 0,
    'contract lists this gate as entry');
  Check(Pos('RawDeflate', LContract) > 0, 'contract names RAW DEFLATE API');
  Check(Pos('TZipAddOptions', LContract) > 0,
    'contract documents add options');
  Check(Pos('TZipExtractOptions', LContract) > 0,
    'contract documents extract options');

  LReadme := ReadText('docs/zip/README.md');
  Check(Pos('Zip64', LReadme) > 0, 'readme covers Zip64');
  Check(Pos('bit 11', LReadme) > 0, 'readme covers UTF-8 flag bit 11');
  Check(Pos('MaxOutputSize', LReadme) > 0, 'readme covers bomb guard');
  Check(Pos('RestoreMode', LReadme) > 0, 'readme covers permission restore');
  Check(Pos('SkipSymlinks', LReadme) > 0, 'readme covers symlink policy');
  Check(Pos('compare_go', LReadme) > 0, 'readme points at Go comparison');

  LRegistry := ReadText('docs/core-module-registry.md');
  Check(Pos('| `zip` |', LRegistry) > 0, 'module registry has zip row');
end;

procedure TestExampleProjectExists;
var
  LLpr, LMakefile: string;
begin
  LLpr := ReadText('examples/nextpas.core.zip/zip_roundtrip/zip_roundtrip.lpr');
  Check(Pos('NewZipWriter', LLpr) > 0, 'example writes an archive');
  Check(Pos('NewZipReader', LLpr) > 0, 'example reads it back');
  LMakefile :=
    ReadText('examples/nextpas.core.zip/zip_roundtrip/Makefile');
  Check(Pos('clean:', LMakefile) > 0, 'example Makefile has clean target');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.contract');
  T.Test('No FPC RTL dependencies', @TestNoFpcRtlDependencies);
  T.Test('No C-style operators', @TestNoCStyleOperators);
  T.Test('Facade purity', @TestFacadePurity);
  T.Test('Docs contract', @TestDocsContract);
  T.Test('Example project exists', @TestExampleProjectExists);
  if not T.Run then Halt(1);
end.
