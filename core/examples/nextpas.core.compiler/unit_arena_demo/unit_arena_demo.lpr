program unit_arena_demo;
{**
 * Product path: nextpas.core.compiler.mem session + unit scopes.
 * Mirrors a multi-unit compile: session owns VirtualArena; UnitBegin/End
 * resets per unit and tracks session peak.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.compiler.mem,
  nextpas.core.mem;

type
  PAstNode = ^TAstNode;
  TAstNode = record
    Kind: LongWord;
    Left, Right: PAstNode;
    Value: LongInt;
  end;

function MakeNode(var ASession: TCompilerSessionScope; AKind: LongWord;
  AValue: LongInt): PAstNode;
begin
  Result := PAstNode(ASession.Alloc(SizeOf(TAstNode)));
  if Result = nil then
    Exit;
  Result^.Kind := AKind;
  Result^.Left := nil;
  Result^.Right := nil;
  Result^.Value := AValue;
end;

var
  LSession: TCompilerSessionScope;
  LRoot, LLeft, LRight: PAstNode;
  LUnits, LPeak: SizeUInt;
  U: Integer;
  LStatsLine: string;

begin
  LPeak := 0;
  LUnits := 0;
  FillChar(LSession, SizeOf(LSession), 0);
  LSession.BeginSession;
  try
    for U := 1 to 8 do
    begin
      LSession.UnitBegin;
      LRoot := MakeNode(LSession, 1, U);
      LLeft := MakeNode(LSession, 2, U * 10);
      LRight := MakeNode(LSession, 3, U * 10 + 1);
      if (LRoot = nil) or (LLeft = nil) or (LRight = nil) then
      begin
        WriteLn('unit-arena-demo=fail');
        WriteLn('error=alloc');
        Halt(1);
      end;
      LRoot^.Left := LLeft;
      LRoot^.Right := LRight;
      LSession.UnitEnd;
      if LSession.SessionPeak > LPeak then
        LPeak := LSession.SessionPeak;
      Inc(LUnits);
    end;
  finally
    LSession.EndSession;
  end;

  LStatsLine := FormatMemStats;
  WriteLn('unit-arena-demo=ready');
  WriteLn('units=', LUnits);
  WriteLn('session-peak=', LPeak);
  WriteLn('scope-active=', Ord(LSession.Active));
  WriteLn('mem-stats=', LStatsLine);
end.
