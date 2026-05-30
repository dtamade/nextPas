unit nextpas.core.regex.compiler;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.regex.base,
  nextpas.core.regex.charclass,
  nextpas.core.regex.parser;

function RegexCompile(ARoot: PAstNode; ANumCaptures: UInt32): TRegexProgram;

implementation

uses SysUtils;

type
  TCompiler = record
    Code: array of TInstruction;
    Count: UInt32;
    Cap: UInt32;
    Classes: array of TCharBitmap;
    NumClasses: UInt32;
    GroupNames: TGroupNameArray;
    NumGroupNames: UInt32;
  end;

procedure Emit(var C: TCompiler; const AInst: TInstruction);
begin
  if C.Count >= C.Cap then
  begin
    if C.Cap = 0 then C.Cap := 64 else C.Cap := C.Cap * 2;
    SetLength(C.Code, C.Cap);
  end;
  C.Code[C.Count] := AInst;
  Inc(C.Count);
end;

function EmitPlaceholder(var C: TCompiler; AOp: TOpCode): UInt32;
var inst: TInstruction;
begin
  FillChar(inst, SizeOf(inst), 0);
  inst.Op := AOp;
  Result := C.Count;
  Emit(C, inst);
end;

function AddClass(var C: TCompiler; const ABitmap: TCharBitmap): UInt16;
begin
  if C.NumClasses >= UInt32(Length(C.Classes)) then
    SetLength(C.Classes, C.NumClasses + 16);
  C.Classes[C.NumClasses] := ABitmap;
  Result := UInt16(C.NumClasses);
  Inc(C.NumClasses);
end;

procedure CompileNode(var C: TCompiler; ANode: PAstNode); forward;

procedure CompileRepeat(var C: TCompiler; ANode: PAstNode);
var splitPC, bodyStart, jumpPC: UInt32; i: UInt32; inst: TInstruction;
begin
  case ANode^.RepeatKind of
    rkZeroOrMore:
    begin
      splitPC := C.Count;
      FillChar(inst, SizeOf(inst), 0);
      inst.Op := opSplit;
      Emit(C, inst);
      bodyStart := C.Count;
      CompileNode(C, ANode^.Left);
      FillChar(inst, SizeOf(inst), 0);
      inst.Op := opJump;
      inst.Target := splitPC;
      Emit(C, inst);
      if ANode^.RepeatGreedy then
      begin
        C.Code[splitPC].X := bodyStart;
        C.Code[splitPC].Y := C.Count;
      end
      else
      begin
        C.Code[splitPC].X := C.Count;
        C.Code[splitPC].Y := bodyStart;
      end;
    end;
    rkOneOrMore:
    begin
      bodyStart := C.Count;
      CompileNode(C, ANode^.Left);
      splitPC := C.Count;
      FillChar(inst, SizeOf(inst), 0);
      inst.Op := opSplit;
      if ANode^.RepeatGreedy then
      begin
        inst.X := bodyStart;
        inst.Y := C.Count + 1;
      end
      else
      begin
        inst.X := C.Count + 1;
        inst.Y := bodyStart;
      end;
      Emit(C, inst);
    end;
    rkZeroOrOne:
    begin
      splitPC := C.Count;
      FillChar(inst, SizeOf(inst), 0);
      inst.Op := opSplit;
      Emit(C, inst);
      bodyStart := C.Count;
      CompileNode(C, ANode^.Left);
      if ANode^.RepeatGreedy then
      begin
        C.Code[splitPC].X := bodyStart;
        C.Code[splitPC].Y := C.Count;
      end
      else
      begin
        C.Code[splitPC].X := C.Count;
        C.Code[splitPC].Y := bodyStart;
      end;
    end;
    rkRange:
    begin
      for i := 0 to ANode^.RepeatMin - 1 do
        CompileNode(C, ANode^.Left);
      if ANode^.RepeatMax = $FFFFFFFF then
      begin
        splitPC := C.Count;
        FillChar(inst, SizeOf(inst), 0);
        inst.Op := opSplit;
        Emit(C, inst);
        bodyStart := C.Count;
        CompileNode(C, ANode^.Left);
        FillChar(inst, SizeOf(inst), 0);
        inst.Op := opJump;
        inst.Target := splitPC;
        Emit(C, inst);
        C.Code[splitPC].X := bodyStart;
        C.Code[splitPC].Y := C.Count;
      end
      else
      begin
        for i := ANode^.RepeatMin to ANode^.RepeatMax - 1 do
        begin
          splitPC := C.Count;
          FillChar(inst, SizeOf(inst), 0);
          inst.Op := opSplit;
          Emit(C, inst);
          CompileNode(C, ANode^.Left);
          C.Code[splitPC].X := splitPC + 1;
          C.Code[splitPC].Y := C.Count;
        end;
      end;
    end;
  end;
end;

procedure CompileNode(var C: TCompiler; ANode: PAstNode);
var inst: TInstruction; splitPC, jumpPC: UInt32;
begin
  if ANode = nil then Exit;
  FillChar(inst, SizeOf(inst), 0);

  case ANode^.Kind of
    akLiteral:
    begin
      inst.Op := opLiteral;
      inst.Ch := ANode^.Ch;
      Emit(C, inst);
    end;
    akAnyChar:
    begin
      inst.Op := opAnyChar;
      Emit(C, inst);
    end;
    akCharClass:
    begin
      inst.Op := opCharClass;
      inst.ClassIdx := AddClass(C, ANode^.ClassBitmap);
      inst.Negated := ANode^.ClassNegated;
      Emit(C, inst);
    end;
    akConcat:
    begin
      CompileNode(C, ANode^.Left);
      CompileNode(C, ANode^.Right);
    end;
    akAlternate:
    begin
      splitPC := C.Count;
      inst.Op := opSplit;
      Emit(C, inst);
      C.Code[splitPC].X := C.Count;
      CompileNode(C, ANode^.Left);
      jumpPC := C.Count;
      inst.Op := opJump;
      inst.Target := 0;
      Emit(C, inst);
      C.Code[splitPC].Y := C.Count;
      CompileNode(C, ANode^.Right);
      C.Code[jumpPC].Target := C.Count;
    end;
    akRepeat:
      CompileRepeat(C, ANode);
    akCapture:
    begin
      if ANode^.CaptureName <> '' then
      begin
        if C.NumGroupNames >= UInt32(Length(C.GroupNames)) then
          SetLength(C.GroupNames, C.NumGroupNames + 8);
        C.GroupNames[C.NumGroupNames].Name := ANode^.CaptureName;
        C.GroupNames[C.NumGroupNames].Index := ANode^.CaptureIndex;
        Inc(C.NumGroupNames);
      end;
      inst.Op := opSave;
      inst.Slot := (ANode^.CaptureIndex + 1) * 2;
      Emit(C, inst);
      CompileNode(C, ANode^.Left);
      inst.Op := opSave;
      inst.Slot := (ANode^.CaptureIndex + 1) * 2 + 1;
      Emit(C, inst);
    end;
    akGroup:
      CompileNode(C, ANode^.Left);
    akAssert:
    begin
      inst.Op := opAssert;
      inst.Assert := ANode^.AssertKind;
      Emit(C, inst);
    end;
  end;
end;

function RegexCompile(ARoot: PAstNode; ANumCaptures: UInt32): TRegexProgram;
var C: TCompiler; inst: TInstruction; i: UInt32;
begin
  FillChar(C, SizeOf(C), 0);
  // Wrap entire pattern in Save(0)...Save(1) for whole-match tracking
  FillChar(inst, SizeOf(inst), 0);
  inst.Op := opSave;
  inst.Slot := 0;
  Emit(C, inst);
  CompileNode(C, ARoot);
  FillChar(inst, SizeOf(inst), 0);
  inst.Op := opSave;
  inst.Slot := 1;
  Emit(C, inst);
  FillChar(inst, SizeOf(inst), 0);
  inst.Op := opMatch;
  Emit(C, inst);

  SetLength(Result.Code, C.Count);
  Move(C.Code[0], Result.Code[0], C.Count * SizeOf(TInstruction));
  SetLength(Result.Classes, C.NumClasses);
  if C.NumClasses > 0 then
    Move(C.Classes[0], Result.Classes[0], C.NumClasses * SizeOf(TCharBitmap));
  Result.NumSlots := (ANumCaptures + 1) * 2;
  Result.NumCaptures := ANumCaptures;
  SetLength(Result.GroupNames, C.NumGroupNames);
  if C.NumGroupNames > 0 then
    Move(C.GroupNames[0], Result.GroupNames[0], C.NumGroupNames * SizeOf(TGroupName));
  Result.LiteralPrefix := '';
  Result.LiteralPrefixLen := 0;

  // Extract literal prefix (skip leading Save instructions)
  i := 0;
  while (i < C.Count) and (Result.Code[i].Op = opSave) do Inc(i);
  if (i < C.Count) and (Result.Code[i].Op = opLiteral) then
  begin
    while (i < C.Count) and (Result.Code[i].Op = opLiteral) do
    begin
      Result.LiteralPrefix := Result.LiteralPrefix + Chr(Result.Code[i].Ch);
      Inc(i);
    end;
    Result.LiteralPrefixLen := Length(Result.LiteralPrefix);
  end;
end;

end.
