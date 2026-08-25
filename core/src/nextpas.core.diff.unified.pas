{**
 * nextpas.core.diff.unified - unified patch 结构化编解码
 *
 * BuildHunks 把 Myers 编辑脚本按上下文宽度分组成 hunk（git 语义：
 * 相邻改动间隙 <= 2*context 时并入同一 hunk）。EmitUnifiedHunks 只产
 * 出 "@@ ... @@" 区段，文件头归调用方；计数为 1 时省略 ",1"，空侧输出
 * "0,0"（与 git 输出一致）。ParseUnified 是宽容读取器：跳过任意文件
 * 头、"\ No newline at end of file" 标记与 funcname 后缀，hunk 行数由
 * 头部计数驱动而非猜测。
 *}

unit nextpas.core.diff.unified;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.diff.base,
  nextpas.core.diff.myers;

{ Group an edit script into unified hunks carrying context lines.
  AContext is the number of unchanged lines shown around each change;
  values below zero are treated as 0. }
function BuildHunks(const AEdits: TDiffEditArray;
  const AOld, ANew: TStringArray; AContext: Integer): TDiffHunkArray;

{ Render hunks as "@@ -a,b +c,d @@" sections. No file headers. }
function EmitUnifiedHunks(const AHunks: TDiffHunkArray): string;

{ Convenience: DiffLines + BuildHunks + EmitUnifiedHunks. }
function EmitUnified(const AOld, ANew: TStringArray;
  AContext: Integer = 3): string;

{ Parse a unified patch (with or without file headers). Returns the
  structured hunks; line indexes are reconstructed from the numbers in
  the "@@" headers. }
function ParseUnified(const AText: string): TDiffHunkArray;

implementation

function IntToStrSafe(AValue: Integer): string;
begin
  Str(AValue, Result);
end;

function IsDigitCh(ACh: Char): Boolean;
begin
  Result := (ACh >= '0') and (ACh <= '9');
end;

{ git-style range: ",0" kept explicit for empty sides, ",1" omitted }
function RangeStr(AStart, ACount: Integer): string;
begin
  if ACount = 0 then
    Result := IntToStrSafe(AStart) + ',0'
  else if ACount = 1 then
    Result := IntToStrSafe(AStart)
  else
    Result := IntToStrSafe(AStart) + ',' + IntToStrSafe(ACount);
end;

function BuildHunks(const AEdits: TDiffEditArray;
  const AOld, ANew: TStringArray; AContext: Integer): TDiffHunkArray;
var
  L, I, J, GroupFirst, GroupLast, ELo, EHi, HunkCount: Integer;
  Changed: array of Boolean;
  OldBef, NewBef: array of Integer;
  Hunks: TDiffHunkArray;

  { Append one hunk covering edits [ALo..AHi]. }
  procedure PushHunk(ALo, AHi: Integer);
  var
    E, Oi, Nj: Integer;
  begin
    SetLength(Hunks, HunkCount + 1);
    with Hunks[HunkCount] do
    begin
      OldStart := 0;
      NewStart := 0;
      OldCount := 0;
      NewCount := 0;
      Lines := nil;
      Oi := OldBef[ALo];
      Nj := NewBef[ALo];
      OldStart := Oi + 1;
      NewStart := Nj + 1;
      for E := ALo to AHi do
      begin
        SetLength(Lines, Length(Lines) + 1);
        with Lines[Length(Lines) - 1] do
        begin
          Action := AEdits[E].Action;
          case Action of
            daEqual:
              begin
                OldIndex := Oi;
                NewIndex := Nj;
                Text := AOld[Oi];
              end;
            daDelete:
              begin
                OldIndex := Oi;
                NewIndex := -1;
                Text := AOld[Oi];
              end;
            daInsert:
              begin
                OldIndex := -1;
                NewIndex := Nj;
                Text := ANew[Nj];
              end;
          end;
        end;
        case AEdits[E].Action of
          daEqual: begin Inc(Oi); Inc(Nj); end;
          daDelete: Inc(Oi);
          daInsert: Inc(Nj);
        end;
      end;
      OldCount := Oi - (OldStart - 1);
      NewCount := Nj - (NewStart - 1);
      // unified convention: an empty side is reported as 0,0 (git does)
      if OldCount = 0 then
        OldStart := 0;
      if NewCount = 0 then
        NewStart := 0;
    end;
    Inc(HunkCount);
  end;

begin
  if AContext < 0 then
    AContext := 0;
  L := Length(AEdits);

  SetLength(Changed, L);
  SetLength(OldBef, L + 1);
  SetLength(NewBef, L + 1);
  OldBef[0] := 0;
  NewBef[0] := 0;
  for I := 0 to L - 1 do
  begin
    Changed[I] := AEdits[I].Action <> daEqual;
    case AEdits[I].Action of
      daEqual:
        begin
          OldBef[I + 1] := OldBef[I] + 1;
          NewBef[I + 1] := NewBef[I] + 1;
        end;
      daDelete:
        begin
          OldBef[I + 1] := OldBef[I] + 1;
          NewBef[I + 1] := NewBef[I];
        end;
      daInsert:
        begin
          OldBef[I + 1] := OldBef[I];
          NewBef[I + 1] := NewBef[I] + 1;
        end;
    end;
  end;

  SetLength(Hunks, 0);
  HunkCount := 0;
  I := 0;
  while I < L do
  begin
    if not Changed[I] then
    begin
      Inc(I);
      Continue;
    end;
    // start a group at this change and absorb later changes whose gap
    // of unchanged lines is small enough (git merge rule)
    GroupFirst := I;
    GroupLast := I;
    J := I + 1;
    while J < L do
    begin
      if Changed[J] then
      begin
        if J - GroupLast <= 2 * AContext + 1 then
        begin
          GroupLast := J;
          Inc(J);
        end
        else
          Break;
      end
      else
        Inc(J);
    end;
    ELo := GroupFirst - AContext;
    if ELo < 0 then
      ELo := 0;
    EHi := GroupLast + AContext;
    if EHi > L - 1 then
      EHi := L - 1;
    PushHunk(ELo, EHi);
    I := GroupLast + 1;
  end;
  Result := Hunks;
end;

function EmitUnifiedHunks(const AHunks: TDiffHunkArray): string;
var
  H, L: Integer;
begin
  Result := '';
  for H := 0 to Length(AHunks) - 1 do
  begin
    Result := Result + '@@ -'
      + RangeStr(AHunks[H].OldStart, AHunks[H].OldCount)
      + ' +'
      + RangeStr(AHunks[H].NewStart, AHunks[H].NewCount)
      + ' @@' + #10;
    for L := 0 to Length(AHunks[H].Lines) - 1 do
    begin
      case AHunks[H].Lines[L].Action of
        daEqual: Result := Result + ' ';
        daDelete: Result := Result + '-';
        daInsert: Result := Result + '+';
      end;
      Result := Result + AHunks[H].Lines[L].Text + #10;
    end;
  end;
end;

function EmitUnified(const AOld, ANew: TStringArray;
  AContext: Integer = 3): string;
begin
  Result := EmitUnifiedHunks(
    BuildHunks(DiffLines(AOld, ANew), AOld, ANew, AContext));
end;

{ Read a decimal number at AP; returns whether any digits were found.
  AP is advanced past them. }
function TryReadInt(const S: string; var AP, AValue: Integer): Boolean;
var
  Start, V: Integer;
begin
  Start := AP;
  V := 0;
  while (AP <= Length(S)) and IsDigitCh(S[AP]) do
  begin
    V := V * 10 + (Ord(S[AP]) - Ord('0'));
    Inc(AP);
  end;
  Result := AP > Start;
  AValue := V;
end;

function ParseUnified(const AText: string): TDiffHunkArray;
var
  Lines: TStringArray;
  Idx: Integer;
  L: string;
  InHunk: Boolean;
  Cur: TDiffHunk;
  EqO, EqN, Oi, Nj: Integer;

  procedure FlushCur;
  begin
    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := Cur;
  end;

  procedure AddLine(AAction: TDiffLineAction; const ATextPart: string);
  begin
    SetLength(Cur.Lines, Length(Cur.Lines) + 1);
    with Cur.Lines[Length(Cur.Lines) - 1] do
    begin
      Action := AAction;
      case AAction of
        daEqual:
          begin
            OldIndex := Oi;
            NewIndex := Nj;
          end;
        daDelete:
          begin
            OldIndex := Oi;
            NewIndex := -1;
          end;
        daInsert:
          begin
            OldIndex := -1;
            NewIndex := Nj;
          end;
      end;
      Text := ATextPart;
    end;
    case AAction of
      daEqual: begin Inc(Oi); Inc(Nj); Inc(EqO); Inc(EqN); end;
      daDelete: begin Inc(Oi); Inc(EqO); end;
      daInsert: begin Inc(Nj); Inc(EqN); end;
    end;
  end;

  { Try to parse "@@ -a[,b] +c[,d] @@" from the front of ALine. }
  function StartHeader(const ALine: string): Boolean;
  var
    P, V: Integer;
  begin
    Result := False;
    if Copy(ALine, 1, 4) <> '@@ -' then
      Exit;
    P := 5;
    if not TryReadInt(ALine, P, V) then
      Exit;
    Cur.OldStart := V;
    Cur.OldCount := 1;
    if (P <= Length(ALine)) and (ALine[P] = ',') then
    begin
      Inc(P);
      if not TryReadInt(ALine, P, V) then
        Exit;
      Cur.OldCount := V;
    end;
    while (P <= Length(ALine)) and (ALine[P] = ' ') do
      Inc(P);
    if (P > Length(ALine)) or (ALine[P] <> '+') then
      Exit;
    Inc(P);
    if not TryReadInt(ALine, P, V) then
      Exit;
    Cur.NewStart := V;
    Cur.NewCount := 1;
    if (P <= Length(ALine)) and (ALine[P] = ',') then
    begin
      Inc(P);
      if not TryReadInt(ALine, P, V) then
        Exit;
      Cur.NewCount := V;
    end;
    Result := True;
  end;

begin
  Result := nil;
  Lines := DiffSplitLines(AText);
  InHunk := False;
  Cur.Lines := nil;
  for Idx := 0 to Length(Lines) - 1 do
  begin
    L := Lines[Idx];
    if InHunk then
    begin
      if (EqO >= Cur.OldCount) and (EqN >= Cur.NewCount) then
      begin
        FlushCur;
        InHunk := False;
      end
      else
      begin
        if (Length(L) > 0) and (L[1] = '\') then
          Continue;   // "\ No newline at end of file" marker
        if Length(L) = 0 then
          Continue;
        case L[1] of
          ' ': AddLine(daEqual, Copy(L, 2, MaxInt));
          '-': AddLine(daDelete, Copy(L, 2, MaxInt));
          '+': AddLine(daInsert, Copy(L, 2, MaxInt));
        end;
        // unrecognized prefixes are skipped; counting stays authoritative
        if (EqO >= Cur.OldCount) and (EqN >= Cur.NewCount) then
        begin
          FlushCur;
          InHunk := False;
        end;
        Continue;
      end;
    end;
    // outside a hunk: only "@@" headers matter, everything else is noise
    if StartHeader(L) then
    begin
      Oi := Cur.OldStart - 1;
      Nj := Cur.NewStart - 1;
      EqO := 0;
      EqN := 0;
      Cur.Lines := nil;
      InHunk := True;
    end;
  end;
  if InHunk then
    FlushCur;   // tolerate truncated patches
end;

end.
