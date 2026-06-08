unit nextpas.core.regex.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.regex.base,
  nextpas.core.regex.charclass;

type
  TAstKind = (
    akLiteral,
    akAnyChar,
    akCharClass,
    akConcat,
    akAlternate,
    akRepeat,
    akCapture,
    akGroup,
    akAssert
  );

  TRepeatKind = (rkZeroOrMore, rkOneOrMore, rkZeroOrOne, rkRange);

  PAstNode = ^TAstNode;
  TAstNode = record
    Kind: TAstKind;
    Ch: Byte;
    ClassBitmap: TCharBitmap;
    ClassNegated: Boolean;
    Left, Right: PAstNode;
    RepeatMin, RepeatMax: UInt32;
    RepeatGreedy: Boolean;
    RepeatKind: TRepeatKind;
    CaptureIndex: UInt32;
    CaptureName: string;
    AssertKind: TAssertKind;
  end;

  TAstNodeArray = array of PAstNode;

function RegexParse(const APattern: string; out ANumCaptures: UInt32; out AFlags: TRegexFlags): PAstNode;
procedure RegexFreeAst(ANode: PAstNode);

implementation

uses
  nextpas.core.errors;

type
  TParser = record
    Pattern: string;
    Pos: SizeUInt;
    NumCaptures: UInt32;
    Depth: UInt32;
    Nodes: array of PAstNode;
    NodeCount: UInt32;
  end;

const
  MAX_REPEAT_COUNT = 1000;
  MAX_NEST_DEPTH = 200;

function NewNode(var P: TParser; AKind: TAstKind): PAstNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(TAstNode), 0);
  Result^.Kind := AKind;
  if P.NodeCount >= UInt32(Length(P.Nodes)) then
    SetLength(P.Nodes, P.NodeCount + 64);
  P.Nodes[P.NodeCount] := Result;
  Inc(P.NodeCount);
end;

procedure RegexFreeAst(ANode: PAstNode);
begin
  if ANode = nil then Exit;
  RegexFreeAst(ANode^.Left);
  RegexFreeAst(ANode^.Right);
  Dispose(ANode);
end;

function Peek(var P: TParser): Char;
begin
  if P.Pos <= Length(P.Pattern) then
    Result := P.Pattern[P.Pos]
  else
    Result := #0;
end;

function Next(var P: TParser): Char;
begin
  Result := Peek(P);
  if P.Pos <= Length(P.Pattern) then
    Inc(P.Pos);
end;

function ParseEscape(var P: TParser): PAstNode;
var ch: Char;
begin
  if P.Pos > Length(P.Pattern) then
    raise ERegexCompileError.Create('trailing backslash', P.Pos);
  ch := Next(P);
  case ch of
    'p': raise ERegexCompileError.Create('Unicode properties not supported', P.Pos);
    'd': begin Result := NewNode(P, akCharClass); CharBitmapInitDigit(Result^.ClassBitmap); end;
    'D': begin Result := NewNode(P, akCharClass); CharBitmapInitDigit(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    'w': begin Result := NewNode(P, akCharClass); CharBitmapInitWord(Result^.ClassBitmap); end;
    'W': begin Result := NewNode(P, akCharClass); CharBitmapInitWord(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    's': begin Result := NewNode(P, akCharClass); CharBitmapInitSpace(Result^.ClassBitmap); end;
    'S': begin Result := NewNode(P, akCharClass); CharBitmapInitSpace(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    'b': begin Result := NewNode(P, akAssert); Result^.AssertKind := akWordBoundary; end;
    'B': begin Result := NewNode(P, akAssert); Result^.AssertKind := akNotWordBoundary; end;
    'n': begin Result := NewNode(P, akLiteral); Result^.Ch := 10; end;
    'r': begin Result := NewNode(P, akLiteral); Result^.Ch := 13; end;
    't': begin Result := NewNode(P, akLiteral); Result^.Ch := 9; end;
  else
    Result := NewNode(P, akLiteral);
    Result^.Ch := Ord(ch);
  end;
end;

procedure AddCharClassEscape(var ABitmap: TCharBitmap; const ACh: Char);
var
  LBitmap: TCharBitmap;
begin
  case ACh of
    'd', 'D':
      CharBitmapInitDigit(LBitmap);
    'w', 'W':
      CharBitmapInitWord(LBitmap);
    's', 'S':
      CharBitmapInitSpace(LBitmap);
  else
    Exit;
  end;

  if ACh in ['D', 'W', 'S'] then
    CharBitmapNegate(LBitmap);
  CharBitmapOr(ABitmap, LBitmap);
end;

function ParseCharClass(var P: TParser): PAstNode;
var negated: Boolean; lo, hi: Byte; ch: Char;
begin
  Result := NewNode(P, akCharClass);
  CharBitmapClear(Result^.ClassBitmap);
  negated := False;
  if Peek(P) = '^' then begin negated := True; Next(P); end;
  Result^.ClassNegated := negated;

  while (Peek(P) <> ']') and (Peek(P) <> #0) do
  begin
    ch := Next(P);
    if ch = '\' then
    begin
      ch := Next(P);
      case ch of
        'd', 'D', 'w', 'W', 's', 'S':
          AddCharClassEscape(Result^.ClassBitmap, ch);
        'n': CharBitmapSet(Result^.ClassBitmap, 10);
        'r': CharBitmapSet(Result^.ClassBitmap, 13);
        't': CharBitmapSet(Result^.ClassBitmap, 9);
      else
        CharBitmapSet(Result^.ClassBitmap, Ord(ch));
      end;
      Continue;
    end;

    lo := Ord(ch);
    if Peek(P) = '-' then
    begin
      Next(P);
      if Peek(P) = ']' then
      begin
        CharBitmapSet(Result^.ClassBitmap, lo);
        CharBitmapSet(Result^.ClassBitmap, Ord('-'));
        Break;
      end;
      hi := Ord(Next(P));
      if lo > hi then
        raise ERegexCompileError.Create('invalid character range', P.Pos);
      CharBitmapSetRange(Result^.ClassBitmap, lo, hi);
    end
    else
      CharBitmapSet(Result^.ClassBitmap, lo);
  end;
  if Peek(P) = ']' then Next(P)
  else
    raise ERegexCompileError.Create('unclosed character class', P.Pos);
end;

function ParseAtom(var P: TParser): PAstNode; forward;
function ParseConcat(var P: TParser): PAstNode; forward;
function ParseAlternate(var P: TParser): PAstNode; forward;

function ParseAtom(var P: TParser): PAstNode;
var ch: Char; LName: string;
begin
  ch := Peek(P);
  case ch of
    #0, '|': Result := nil;
    ')':
    begin
      if P.Depth = 0 then
        raise ERegexCompileError.Create('unmatched closing parenthesis', P.Pos);
      Result := nil;
    end;
    '*', '+', '?', '{':
      raise ERegexCompileError.Create('quantifier without preceding atom', P.Pos);
    '.': begin Next(P); Result := NewNode(P, akAnyChar); end;
    '^': begin Next(P); Result := NewNode(P, akAssert); Result^.AssertKind := akStart; end;
    '$': begin Next(P); Result := NewNode(P, akAssert); Result^.AssertKind := akEnd; end;
    '\': begin Next(P); Result := ParseEscape(P); end;
    '[': begin Next(P); Result := ParseCharClass(P); end;
    '(':
    begin
      Next(P);
      Inc(P.Depth);
      if P.Depth > MAX_NEST_DEPTH then
        raise ERegexCompileError.Create('nesting depth exceeds limit', P.Pos);
      if (Peek(P) = '?') then
      begin
        Next(P);
        if Peek(P) = ':' then
        begin
          Next(P);
          Result := NewNode(P, akGroup);
          Result^.Left := ParseAlternate(P);
        end
        else if (Peek(P) = 'P') or (Peek(P) = '<') then
        begin
          // Named group: (?P<name>...) or (?<name>...)
          if Peek(P) = 'P' then
          begin
            Next(P);
            if Peek(P) <> '<' then
              raise ERegexCompileError.Create('malformed named group', P.Pos);
          end;
          Next(P);  // skip <
          LName := '';
          while (Peek(P) <> '>') and (Peek(P) <> #0) do
            LName := LName + Next(P);
          if Peek(P) <> '>' then
            raise ERegexCompileError.Create('unclosed named group', P.Pos);
          if LName = '' then
            raise ERegexCompileError.Create('empty named group', P.Pos);
          Next(P);
          Result := NewNode(P, akCapture);
          Result^.CaptureIndex := P.NumCaptures;
          Result^.CaptureName := LName;
          Inc(P.NumCaptures);
          Result^.Left := ParseAlternate(P);
        end
        else
          raise ERegexCompileError.Create('unknown group modifier', P.Pos);
      end
      else
      begin
        Result := NewNode(P, akCapture);
        Result^.CaptureIndex := P.NumCaptures;
        Inc(P.NumCaptures);
        Result^.Left := ParseAlternate(P);
      end;
      if Peek(P) = ')' then begin Next(P); Dec(P.Depth); end
      else
        raise ERegexCompileError.Create('unclosed group', P.Pos);
    end;
  else
    Next(P);
    Result := NewNode(P, akLiteral);
    Result^.Ch := Ord(ch);
  end;
end;

function ParseRepeat(var P: TParser): PAstNode;
var atom: PAstNode; ch: Char; rep: PAstNode;
    minV, maxV: UInt32; s: string;
begin
  atom := ParseAtom(P);
  if atom = nil then Exit(nil);

  ch := Peek(P);
  case ch of
    '*', '+', '?':
    begin
      Next(P);
      rep := NewNode(P, akRepeat);
      rep^.Left := atom;
      rep^.RepeatGreedy := True;
      case ch of
        '*': begin rep^.RepeatKind := rkZeroOrMore; rep^.RepeatMin := 0; rep^.RepeatMax := $FFFFFFFF; end;
        '+': begin rep^.RepeatKind := rkOneOrMore; rep^.RepeatMin := 1; rep^.RepeatMax := $FFFFFFFF; end;
        '?': begin rep^.RepeatKind := rkZeroOrOne; rep^.RepeatMin := 0; rep^.RepeatMax := 1; end;
      end;
      if Peek(P) = '?' then begin Next(P); rep^.RepeatGreedy := False; end;
      Result := rep;
    end;
    '{':
    begin
      Next(P);
      s := '';
      while (Peek(P) >= '0') and (Peek(P) <= '9') do begin s := s + Next(P); end;
      if (s = '') and (Peek(P) = ',') then
        raise ERegexCompileError.Create('missing quantifier minimum', P.Pos);
      minV := StrToIntDef(s, 0);
      maxV := minV;
      if Peek(P) = ',' then
      begin
        Next(P);
        s := '';
        while (Peek(P) >= '0') and (Peek(P) <= '9') do begin s := s + Next(P); end;
        if s = '' then maxV := $FFFFFFFF
        else maxV := StrToIntDef(s, minV);
      end;
      if Peek(P) <> '}' then
        raise ERegexCompileError.Create('unclosed quantifier', P.Pos);
      Next(P);
      if (maxV <> $FFFFFFFF) and (minV > maxV) then
        raise ERegexCompileError.Create('quantifier min exceeds max', P.Pos);
      if minV > MAX_REPEAT_COUNT then
        raise ERegexCompileError.Create('repeat count exceeds limit', P.Pos);
      if (maxV <> $FFFFFFFF) and (maxV > MAX_REPEAT_COUNT) then
        raise ERegexCompileError.Create('repeat count exceeds limit', P.Pos);
      rep := NewNode(P, akRepeat);
      rep^.Left := atom;
      rep^.RepeatKind := rkRange;
      rep^.RepeatMin := minV;
      rep^.RepeatMax := maxV;
      rep^.RepeatGreedy := True;
      if Peek(P) = '?' then begin Next(P); rep^.RepeatGreedy := False; end;
      Result := rep;
    end;
  else
    Result := atom;
  end;
end;

function ParseConcat(var P: TParser): PAstNode;
var left, right: PAstNode; concat: PAstNode;
begin
  left := ParseRepeat(P);
  if left = nil then Exit(nil);

  right := ParseRepeat(P);
  if right = nil then Exit(left);

  concat := NewNode(P, akConcat);
  concat^.Left := left;
  concat^.Right := right;

  while True do
  begin
    right := ParseRepeat(P);
    if right = nil then Break;
    left := concat;
    concat := NewNode(P, akConcat);
    concat^.Left := left;
    concat^.Right := right;
  end;
  Result := concat;
end;

function ParseAlternate(var P: TParser): PAstNode;
var left, right, alt: PAstNode;
begin
  left := ParseConcat(P);
  if Peek(P) <> '|' then Exit(left);

  Next(P);
  right := ParseAlternate(P);
  alt := NewNode(P, akAlternate);
  alt^.Left := left;
  alt^.Right := right;
  Result := alt;
end;

function RegexParse(const APattern: string; out ANumCaptures: UInt32; out AFlags: TRegexFlags): PAstNode;
var P: TParser; i: UInt32;
begin
  P.Pattern := APattern;
  P.Pos := 1;
  P.NumCaptures := 0;
  P.Depth := 0;
  P.NodeCount := 0;
  P.Nodes := nil;
  AFlags := [];

  // Check for inline (?i) at pattern start
  if (Length(APattern) >= 4) and (APattern[1] = '(') and (APattern[2] = '?') and
     (APattern[3] = 'i') and (APattern[4] = ')') then
  begin
    AFlags := [rfCaseInsensitive];
    P.Pos := 5;
  end;

  try
    Result := ParseAlternate(P);
  except
    if P.NodeCount > 0 then
      for i := 0 to P.NodeCount - 1 do
      begin
        P.Nodes[i]^.CaptureName := '';
        Dispose(P.Nodes[i]);
      end;
    raise;
  end;
  ANumCaptures := P.NumCaptures;
end;

end.
