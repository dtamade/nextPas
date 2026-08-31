{**
 * nextpas.core.diff.myers - Myers O(ND) 行级 diff
 *
 * 产出最短编辑脚本（daEqual/daDelete/daInsert 序列，索引 0-based）。
 * 工程纪律：公共前缀/后缀先行剥离（大幅缩小 D 上限），任一侧为空的
 * 中段走显式快路径。追踪矩阵内存为 O(D·(N+M))，适合源码级文本，
 * 不适合超大单行 blob（见 docs/diff/README.md Known Limits）。
 *}

unit nextpas.core.diff.myers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.diff.base;

{ Compute the shortest edit script turning AOld into ANew.
  Both arrays are treated as line sequences; ordering is preserved. }
function DiffLines(const AOld, ANew: TStringArray): TDiffEditArray;

implementation

type
  TIntArray = array of Integer;

procedure GrowEdits(var AEdits: TDiffEditArray; const ANeeded: Integer);
var
  Cap: Integer;
begin
  Cap := Length(AEdits);
  if ANeeded <= Cap then
    Exit;
  if Cap = 0 then
    Cap := 64;
  while Cap < ANeeded do
    Cap := Cap * 2;
  SetLength(AEdits, Cap);
end;

{ Middle-segment Myers core. Writes the script in REVERSE order into
  AEdits[0..ACount-1]; caller reverses afterwards. ABaseO/ABaseN are
  offsets into the original arrays so indexes stay global. }
procedure RunMyers(const AOld, ANew: TStringArray;
  ABaseO, ABaseN, ALenO, ALenN: Integer;
  var AEdits: TDiffEditArray; var ACount: Integer);

  procedure Add(AAction: TDiffLineAction; AOldIdx, ANewIdx: Integer);
  begin
    GrowEdits(AEdits, ACount + 1);
    AEdits[ACount].Action := AAction;
    AEdits[ACount].OldIndex := AOldIdx;
    AEdits[ACount].NewIndex := ANewIdx;
    Inc(ACount);
  end;

var
  Max, VOff: Integer;
  V: TIntArray;
  Trace: array of TIntArray;
  D, K, X, Y, PK, PX, PY, Rd: Integer;
  Found: Boolean;
begin
  ACount := 0;
  if (ALenO = 0) and (ALenN = 0) then
    Exit;
  // fast paths: one-sided middles cannot benefit from the frontier walk
  if ALenO = 0 then
  begin
    for D := ALenN - 1 downto 0 do
      Add(daInsert, -1, ABaseN + D);
    Exit;
  end;
  if ALenN = 0 then
  begin
    for D := ALenO - 1 downto 0 do
      Add(daDelete, ABaseO + D, -1);
    Exit;
  end;

  Max := ALenO + ALenN;
  VOff := Max;
  SetLength(V, 2 * Max + 1);

  Found := False;
  D := 0;
  for D := 0 to Max do
  begin
    K := -D;
    while (K <= D) and not Found do
    begin
      if (K = -D) or ((K <> D) and (V[VOff + K - 1] < V[VOff + K + 1])) then
        X := V[VOff + K + 1]
      else
        X := V[VOff + K - 1] + 1;
      Y := X - K;
      while (X < ALenO) and (Y < ALenN)
        and (AOld[ABaseO + X] = ANew[ABaseN + Y]) do
      begin
        Inc(X);
        Inc(Y);
      end;
      V[VOff + K] := X;
      if (X >= ALenO) and (Y >= ALenN) then
        Found := True;
      Inc(K, 2);
    end;
    // snapshot this round's frontier for backtracking; slots above the
    // current K hold stale values but backtracking never visits them
    SetLength(Trace, D + 1);
    Trace[D] := Copy(V, 0, Length(V));
    if Found then
      Break;
  end;

  // walk the rounds backwards emitting one edit plus its snake per round
  X := ALenO;
  Y := ALenN;
  for Rd := D downto 1 do
  begin
    K := X - Y;
    if (K = -Rd) or ((K <> Rd) and (Trace[Rd][VOff + K - 1] < Trace[Rd][VOff + K + 1])) then
      PK := K + 1
    else
      PK := K - 1;
    PX := Trace[Rd][VOff + PK];
    PY := PX - PK;
    while (X > PX) and (Y > PY) do
    begin
      Add(daEqual, ABaseO + X - 1, ABaseN + Y - 1);
      Dec(X);
      Dec(Y);
    end;
    if X = PX then
    begin
      Add(daInsert, -1, ABaseN + Y - 1);
      Dec(Y);
    end
    else
    begin
      Add(daDelete, ABaseO + X - 1, -1);
      Dec(X);
    end;
  end;
  // initial snake of round zero
  while (X > 0) and (Y > 0) do
  begin
    Add(daEqual, ABaseO + X - 1, ABaseN + Y - 1);
    Dec(X);
    Dec(Y);
  end;
end;

function DiffLines(const AOld, ANew: TStringArray): TDiffEditArray;
var
  N, M, Pfx, Sfx, I: Integer;
  Mid: TDiffEditArray;
  MidCount, Tmp: Integer;
  SwapEdit: TDiffEdit;
begin
  Result := nil;
  N := Length(AOld);
  M := Length(ANew);

  // common prefix emits in forward order directly; keep physical length
  // equal to logical length so later splicing can trust Length()
  SetLength(Result, 0);
  Pfx := 0;
  while (Pfx < N) and (Pfx < M) and (AOld[Pfx] = ANew[Pfx]) do
  begin
    SetLength(Result, Pfx + 1);
    Result[Pfx].Action := daEqual;
    Result[Pfx].OldIndex := Pfx;
    Result[Pfx].NewIndex := Pfx;
    Inc(Pfx);
  end;

  // common suffix counted first, emitted after the middle
  Sfx := 0;
  while (Sfx < N - Pfx) and (Sfx < M - Pfx)
    and (AOld[N - 1 - Sfx] = ANew[M - 1 - Sfx]) do
    Inc(Sfx);

  Mid := nil;
  RunMyers(AOld, ANew, Pfx, Pfx, N - Sfx - Pfx, M - Sfx - Pfx, Mid, MidCount);

  // middle was collected backwards; reverse it before splicing
  for I := 0 to MidCount div 2 - 1 do
  begin
    SwapEdit := Mid[I];
    Mid[I] := Mid[MidCount - 1 - I];
    Mid[MidCount - 1 - I] := SwapEdit;
  end;

  Tmp := Length(Result);
  GrowEdits(Result, Tmp + MidCount + Sfx);
  if MidCount > 0 then
    Move(Mid[0], Result[Tmp], SizeOf(TDiffEdit) * MidCount);
  Tmp := Tmp + MidCount;
  for I := 0 to Sfx - 1 do
  begin
    Result[Tmp + I].Action := daEqual;
    Result[Tmp + I].OldIndex := N - Sfx + I;
    Result[Tmp + I].NewIndex := M - Sfx + I;
  end;
  Tmp := Tmp + Sfx;
  SetLength(Result, Tmp);
end;

end.
