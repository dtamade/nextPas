program test_snapshot;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.agent.snapshot,
  nextpas.core.agent.base,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.grapheme;

procedure TestBudgetBoundaries;
var
  S: string;
  Ms: TMessageArray;
begin
  S := BuildBoundedSnapshot('sys', nil, 6000);
  Check(S = 'sys', 'empty messages returns system');
  Check(Length(S) <= 6000, 'within budget');
  Check(CBoundedSnapshotBudget = 6000, 'default budget 6000');
  // over budget truncates (snapshot only aggregates mrSystem)
  SetLength(Ms, 1);
  Ms[0] := Default(TMessage);
  Ms[0].Role := mrSystem;
  SetLength(Ms[0].Parts, 1);
  Ms[0].Parts[0] := Default(TPart);
  Ms[0].Parts[0].Kind := pkText;
  Ms[0].Parts[0].Text := 'hello world hello world hello world';
  S := BuildBoundedSnapshot('', Ms, 5);
  Check(Length(S) <= 5, 'truncated to budget');
  Check(S <> '', 'non-empty truncated');
  // exact budget
  S := BuildBoundedSnapshot('abc', nil, 3);
  Check(S = 'abc', 'exact budget no truncate');
  // tiny budget
  S := BuildBoundedSnapshot('abcdef', nil, 2);
  Check(Length(S) <= 2, 'tiny budget');
end;

procedure TestUtf8Safe;
var
  S, T: string;
begin
  // "é" = 2 bytes, budget 1 -> should truncate to empty or safe boundary
  S := 'ééé'; // 6 bytes
  T := BuildBoundedSnapshot(S, nil, 1);
  Check(Length(T) <= 1, 'utf8 budget 1 safe');
  // verify returned string is valid utf8 (no half char) via roundtrip
  Check(AgentUtf8SafeCutLen(T, 10) = Length(T), 'result is utf8 safe');
  // 3-byte char "中"
  S := '中文测试';
  T := BuildBoundedSnapshot(S, nil, 4);
  Check(Length(T) <= 4, '3-byte trunc within budget');
  Check(AgentUtf8SafeCutLen(T, 10) = Length(T), '3-byte result safe');
end;

procedure TestGraphemeCluster;
var
  S, T: string;
  LG: TGraphemeResult;
begin
  // family emoji 👨‍👩‍👧 = ZWJ sequence, should not be half-cut
  S := 'a👨‍👩‍👧b';
  // force cut inside cluster: full is 1 + 11? bytes (?) +1, budget 5 should land before cluster or after, not inside
  T := BuildBoundedSnapshot(S, nil, 5);
  Check(Length(T) <= 5, 'family budget 5');
  // T should be either "a" or "a<full cluster>" but not half
  // verify last grapheme boundary aligns
  if Length(T) > 1 then
  begin
    LG := GraphemeNext(@T[1], Length(T));
    Check(LG.ByteLen > 0, 'grapheme valid');
  end;
  Check(Pos('�', T) = 0, 'no replacement half-cut for family');

  // flag 🇨🇳 = 8 bytes (2 regional indicators)
  S := 'x🇨🇳y';
  T := BuildBoundedSnapshot(S, nil, 3);
  Check(Length(T) <= 3, 'flag budget 3');
  Check(AgentUtf8SafeCutLen(T, 10) = Length(T), 'flag utf8 safe');

  // keycap 1️⃣ = 6 bytes (1 + VS16 + ZWJ? actually 3+3)
  S := 'a1️⃣b';
  T := BuildBoundedSnapshot(S, nil, 4);
  Check(Length(T) <= 4, 'keycap budget 4 safe');

  // combining: e + acute
  S := 'e'#776'a'; // e + combining diaeresis
  T := BuildBoundedSnapshot(S, nil, 2);
  Check(Length(T) <= 2, 'combining budget 2');
end;

procedure TestAsciiFastPath;
var
  S, T: string;
  i: Integer;
  M: TMessage;
begin
  S := '';
  for i := 1 to 10000 do S := S + 'a';
  T := BuildBoundedSnapshot(S, nil, 6000);
  Check(Length(T) = 6000, 'ascii fast path exact 6000');
  for i := 1 to Length(T) do Check(T[i] = 'a', 'ascii content preserved');
  // ascii with system+messages merged
  M := Default(TMessage);
  M.Role := mrSystem;
  SetLength(M.Parts, 1);
  M.Parts[0] := Default(TPart);
  M.Parts[0].Kind := pkText;
  M.Parts[0].Text := S;
  T := BuildBoundedSnapshot('sys', [M], 6000);
  Check(Length(T) <= 6000, 'ascii merged within budget');
  Check(Length(T) = 6000, 'ascii merged exact');
end;

procedure TestTokensAndCost;
var
  S: string;
  Tk, Cost: Int64;
begin
  S := BuildBoundedSnapshot('hello world', nil, 6000);
  Tk := BoundedSnapshotTokens(S);
  Check(Tk > 0, 'tokens positive');
  Cost := BoundedSnapshotCost(S, 10);
  Check(Cost >= 0, 'cost non-negative');
  Check(BoundedSnapshotTokens('') = 0, 'empty zero tokens');
end;

var
  Suite: TTestSuite;
begin
  Suite := TTestSuite.Create('nextpas.core.agent.snapshot');
  Suite.Test('budget boundaries', @TestBudgetBoundaries);
  Suite.Test('utf8 safe', @TestUtf8Safe);
  Suite.Test('grapheme cluster', @TestGraphemeCluster);
  Suite.Test('ascii fast path', @TestAsciiFastPath);
  Suite.Test('tokens and cost', @TestTokensAndCost);
  if not Suite.Run then Halt(1);
end.
