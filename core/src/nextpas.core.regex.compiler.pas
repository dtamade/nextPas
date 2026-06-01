unit nextpas.core.regex.compiler;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.regex.base,
  nextpas.core.regex.charclass,
  nextpas.core.regex.parser;

function RegexCompile(ARoot: PAstNode; ANumCaptures: UInt32; AFlags: TRegexFlags): TRegexProgram;

implementation

uses nextpas.core.errors;

type
  TCompiler = record
    Code: array of TInstruction;
    Count: UInt32;
    Cap: UInt32;
    Classes: array of TCharBitmap;
    NumClasses: UInt32;
    GroupNames: TGroupNameArray;
    NumGroupNames: UInt32;
    Flags: TRegexFlags;
  end;

const
  MAX_PROGRAM_LEN = 10000;

procedure Emit(var C: TCompiler; const AInst: TInstruction);
begin
  if C.Count >= MAX_PROGRAM_LEN then
    raise ERegexCompileError.Create('compiled program too large', 0);
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
      if ANode^.RepeatMin > 0 then
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
      else if ANode^.RepeatMax > ANode^.RepeatMin then
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
    ciBitmap: TCharBitmap;
    chLo, chHi: Byte;
begin
  if ANode = nil then Exit;
  FillChar(inst, SizeOf(inst), 0);

  case ANode^.Kind of
    akLiteral:
    begin
      if (rfCaseInsensitive in C.Flags) and
         (((ANode^.Ch >= Ord('A')) and (ANode^.Ch <= Ord('Z'))) or
          ((ANode^.Ch >= Ord('a')) and (ANode^.Ch <= Ord('z')))) then
      begin
        // Emit as char class with both cases
        chLo := ANode^.Ch or $20;  // to lowercase
        chHi := ANode^.Ch and (not Byte($20));  // to uppercase
        CharBitmapClear(ciBitmap);
        CharBitmapSet(ciBitmap, chLo);
        CharBitmapSet(ciBitmap, chHi);
        inst.Op := opCharClass;
        inst.ClassIdx := AddClass(C, ciBitmap);
        inst.Negated := False;
        Emit(C, inst);
      end
      else
      begin
        inst.Op := opLiteral;
        inst.Ch := ANode^.Ch;
        Emit(C, inst);
      end;
    end;
    akAnyChar:
    begin
      inst.Op := opAnyChar;
      Emit(C, inst);
    end;
    akCharClass:
    begin
      inst.Op := opCharClass;
      if rfCaseInsensitive in C.Flags then
      begin
        ciBitmap := ANode^.ClassBitmap;
        // Expand bitmap to include both cases for all letters
        for chLo := Ord('a') to Ord('z') do
        begin
          chHi := chLo - 32; // uppercase
          if CharBitmapTest(ciBitmap, chLo) then
            CharBitmapSet(ciBitmap, chHi);
          if CharBitmapTest(ciBitmap, chHi) then
            CharBitmapSet(ciBitmap, chLo);
        end;
        inst.ClassIdx := AddClass(C, ciBitmap);
      end
      else
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

function RegexCompile(ARoot: PAstNode; ANumCaptures: UInt32; AFlags: TRegexFlags): TRegexProgram;
var C: TCompiler; inst: TInstruction; i, j, k: UInt32;
    visited: array of Boolean;
    startBitmap, classBitmap: TCharBitmap;
    startClassFull: Boolean;
    LIsLitAlt: Boolean;
    LLitAltCount: UInt32;
    LLitAlts: array of string;
    LBranchStart: UInt32;
    LLit: string;
    LIsCaseFold: Boolean;
    LCaseFoldStr: string;
    LPopCnt: UInt32;
    LLowByte: Byte;

  procedure CollectStartBytes(APC: UInt32);
  var LInst: TInstruction;
  begin
    if startClassFull then Exit;
    if APC >= C.Count then Exit;
    if visited[APC] then Exit;
    visited[APC] := True;
    LInst := C.Code[APC];
    case LInst.Op of
      opSave: CollectStartBytes(APC + 1);
      opJump: CollectStartBytes(LInst.Target);
      opSplit: begin CollectStartBytes(LInst.X); CollectStartBytes(LInst.Y); end;
      opAssert: CollectStartBytes(APC + 1);
      opLiteral: CharBitmapSet(startBitmap, LInst.Ch);
      opCharClass:
      begin
        classBitmap := Result.Classes[LInst.ClassIdx];
        if LInst.Negated then CharBitmapNegate(classBitmap);
        CharBitmapOr(startBitmap, classBitmap);
      end;
      opAnyChar: startClassFull := True;
      opMatch: startClassFull := True;
    end;
  end;

begin
  Result := Default(TRegexProgram);
  FillChar(C, SizeOf(C), 0);
  C.Flags := AFlags;
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
    for i := 0 to C.NumGroupNames - 1 do
      Result.GroupNames[i] := C.GroupNames[i];
  Result.Flags := AFlags;
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

  // Detect pure literal pattern: opSave(0), opLiteral*, opSave(1), opMatch
  // No char classes, no splits, no asserts, no quantifiers
  Result.IsPureLiteral := False;
  if (Result.LiteralPrefixLen > 0) and (AFlags = []) then
  begin
    i := 0;
    // Skip leading opSave instructions
    while (i < C.Count) and (Result.Code[i].Op = opSave) do Inc(i);
    // Check all remaining are opLiteral until opSave(1) + opMatch
    while (i < C.Count) and (Result.Code[i].Op = opLiteral) do Inc(i);
    // Should be opSave(1) then opMatch
    if (i < C.Count) and (Result.Code[i].Op = opSave) then Inc(i);
    if (i < C.Count) and (Result.Code[i].Op = opMatch) and (i = C.Count - 1) then
      Result.IsPureLiteral := True;
  end;

  Result.IsLiteralAlt := False;
  Result.LiteralAltPatterns := nil;
  if (not Result.IsPureLiteral) and (AFlags = []) then
  begin
    i := 0;
    while (i < C.Count) and (Result.Code[i].Op = opSave) do Inc(i);
    if (i < C.Count) and (Result.Code[i].Op = opSplit) then
    begin
      LIsLitAlt := True;
      LLitAltCount := 0;
      SetLength(LLitAlts, 32);
      j := i;
      while (j < C.Count) and LIsLitAlt do
      begin
        if Result.Code[j].Op = opSplit then
        begin
          LBranchStart := Result.Code[j].X;
          j := Result.Code[j].Y;
        end
        else
        begin
          LBranchStart := j;
          j := C.Count;
        end;
        LLit := '';
        k := LBranchStart;
        while (k < C.Count) and (Result.Code[k].Op = opLiteral) do
        begin
          LLit := LLit + Chr(Result.Code[k].Ch);
          Inc(k);
        end;
        if LLit = '' then
        begin
          LIsLitAlt := False;
          Break;
        end;
        if (k < C.Count) and (Result.Code[k].Op = opJump) then
        begin
          if Result.Code[k].Target < C.Count then
          begin
            LBranchStart := Result.Code[k].Target;
            while (LBranchStart < C.Count) and (Result.Code[LBranchStart].Op = opSave) do
              Inc(LBranchStart);
            if (LBranchStart >= C.Count) or (Result.Code[LBranchStart].Op <> opMatch) then
            begin
              LIsLitAlt := False;
              Break;
            end;
          end;
        end
        else if (k < C.Count) and (Result.Code[k].Op <> opSave) and
                (Result.Code[k].Op <> opMatch) then
        begin
          LIsLitAlt := False;
          Break;
        end;
        if LLitAltCount >= Length(LLitAlts) then
          SetLength(LLitAlts, LLitAltCount * 2);
        LLitAlts[LLitAltCount] := LLit;
        Inc(LLitAltCount);
      end;
      if LIsLitAlt and (LLitAltCount >= 2) then
      begin
        Result.IsLiteralAlt := True;
        SetLength(Result.LiteralAltPatterns, LLitAltCount);
        for k := 0 to LLitAltCount - 1 do
          Result.LiteralAltPatterns[k] := LLitAlts[k];
      end;
    end;
  end;

  Result.IsCaseFoldLiteral := False;
  Result.CaseFoldLiteral := '';
  if (not Result.IsPureLiteral) and (not Result.IsLiteralAlt) and
     (rfCaseInsensitive in AFlags) then
  begin
    i := 0;
    while (i < C.Count) and (Result.Code[i].Op = opSave) do Inc(i);
    LIsCaseFold := True;
    LCaseFoldStr := '';
    while (i < C.Count) and LIsCaseFold do
    begin
      if Result.Code[i].Op = opLiteral then
      begin
        LCaseFoldStr := LCaseFoldStr + Chr(Result.Code[i].Ch);
        Inc(i);
      end
      else if Result.Code[i].Op = opCharClass then
      begin
        LPopCnt := CharBitmapPopCount(Result.Classes[Result.Code[i].ClassIdx]);
        if (LPopCnt = 2) and (not Result.Code[i].Negated) then
        begin
          LLowByte := 0;
          for j := 0 to 255 do
            if CharBitmapTest(Result.Classes[Result.Code[i].ClassIdx], j) then
            begin
              LLowByte := j;
              Break;
            end;
          if (LLowByte >= Ord('A')) and (LLowByte <= Ord('Z')) and
             CharBitmapTest(Result.Classes[Result.Code[i].ClassIdx], LLowByte + 32) then
            LCaseFoldStr := LCaseFoldStr + Chr(LLowByte + 32)
          else if (LLowByte >= Ord('a')) and (LLowByte <= Ord('z')) and
             CharBitmapTest(Result.Classes[Result.Code[i].ClassIdx], LLowByte - 32) then
            LCaseFoldStr := LCaseFoldStr + Chr(LLowByte)
          else
          begin
            LIsCaseFold := False;
            Break;
          end;
          Inc(i);
        end
        else
        begin
          LIsCaseFold := False;
        end;
      end
      else if (Result.Code[i].Op = opSave) or (Result.Code[i].Op = opMatch) then
        Break
      else
        LIsCaseFold := False;
    end;
    if LIsCaseFold and (Length(LCaseFoldStr) > 0) then
    begin
      while (i < C.Count) and (Result.Code[i].Op = opSave) do Inc(i);
      if (i < C.Count) and (Result.Code[i].Op = opMatch) and (i = C.Count - 1) then
      begin
        Result.IsCaseFoldLiteral := True;
        Result.CaseFoldLiteral := LCaseFoldStr;
      end;
    end;
  end;

  // Compute start byte class (set of bytes that can begin a match)
  CharBitmapClear(startBitmap);
  startClassFull := False;
  SetLength(visited, C.Count);
  FillChar(visited[0], C.Count, 0);
  CollectStartBytes(0);
  if startClassFull or (Result.LiteralPrefixLen > 0) then
    Result.StartClassSize := 256
  else
  begin
    Result.StartClass := startBitmap;
    Result.StartClassSize := CharBitmapPopCount(startBitmap);
  end;
end;

end.
