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
  C_TAR_UNITS: array[0..6] of string = (
    'src/nextpas.core.tar.pas',
    'src/nextpas.core.tar.base.pas',
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

begin
  Suite:=TTestSuite.Create('tar.contract');
  Suite.Test('no fpc rtl', @TestNoFpcRtl);
  Suite.Test('no coperators', @TestNoCOperators);
  Suite.Test('facade purity', @TestFacadePurity);
  Suite.Test('docs', @TestDocs);
  if not Suite.Run then Halt(1);
end.
