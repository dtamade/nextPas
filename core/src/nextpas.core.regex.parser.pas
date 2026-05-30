unit nextpas.core.regex.parser;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
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

function RegexParse(const APattern: string; out ANumCaptures: UInt32): PAstNode;
procedure RegexFreeAst(ANode: PAstNode);

implementation

type
  TParser = record
    Pattern: string;
    Pos: SizeUInt;
    NumCaptures: UInt32;
  end;

function NewNode(AKind: TAstKind): PAstNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(TAstNode), 0);
  Result^.Kind := AKind;
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
  ch := Next(P);
  case ch of
    'd': begin Result := NewNode(akCharClass); CharBitmapInitDigit(Result^.ClassBitmap); end;
    'D': begin Result := NewNode(akCharClass); CharBitmapInitDigit(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    'w': begin Result := NewNode(akCharClass); CharBitmapInitWord(Result^.ClassBitmap); end;
    'W': begin Result := NewNode(akCharClass); CharBitmapInitWord(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    's': begin Result := NewNode(akCharClass); CharBitmapInitSpace(Result^.ClassBitmap); end;
    'S': begin Result := NewNode(akCharClass); CharBitmapInitSpace(Result^.ClassBitmap); Result^.ClassNegated := True; end;
    'b': begin Result := NewNode(akAssert); Result^.AssertKind := akWordBoundary; end;
    'B': begin Result := NewNode(akAssert); Result^.AssertKind := akNotWordBoundary; end;
    'n': begin Result := NewNode(akLiteral); Result^.Ch := 10; end;
    'r': begin Result := NewNode(akLiteral); Result^.Ch := 13; end;
    't': begin Result := NewNode(akLiteral); Result^.Ch := 9; end;
  else
    Result := NewNode(akLiteral);
    Result^.Ch := Ord(ch);
  end;
end;

function ParseCharClass(var P: TParser): PAstNode;
var negated: Boolean; lo, hi: Byte; ch: Char;
begin
  Result := NewNode(akCharClass);
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
        'd': CharBitmapSetRange(Result^.ClassBitmap, Ord('0'), Ord('9'));
        'w': begin
          CharBitmapSetRange(Result^.ClassBitmap, Ord('a'), Ord('z'));
          CharBitmapSetRange(Result^.ClassBitmap, Ord('A'), Ord('Z'));
          CharBitmapSetRange(Result^.ClassBitmap, Ord('0'), Ord('9'));
          CharBitmapSet(Result^.ClassBitmap, Ord('_'));
        end;
        's': begin
          CharBitmapSet(Result^.ClassBitmap, 9);
          CharBitmapSet(Result^.ClassBitmap, 10);
          CharBitmapSet(Result^.ClassBitmap, 13);
          CharBitmapSet(Result^.ClassBitmap, 32);
        end;
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
      CharBitmapSetRange(Result^.ClassBitmap, lo, hi);
    end
    else
      CharBitmapSet(Result^.ClassBitmap, lo);
  end;
  if Peek(P) = ']' then Next(P);
end;

function ParseAtom(var P: TParser): PAstNode; forward;
function ParseConcat(var P: TParser): PAstNode; forward;
function ParseAlternate(var P: TParser): PAstNode; forward;

function ParseAtom(var P: TParser): PAstNode;
var ch: Char; LName: string;
begin
  ch := Peek(P);
  case ch of
    #0, ')', '|': Result := nil;
    '.': begin Next(P); Result := NewNode(akAnyChar); end;
    '^': begin Next(P); Result := NewNode(akAssert); Result^.AssertKind := akStart; end;
    '$': begin Next(P); Result := NewNode(akAssert); Result^.AssertKind := akEnd; end;
    '\': begin Next(P); Result := ParseEscape(P); end;
    '[': begin Next(P); Result := ParseCharClass(P); end;
    '(':
    begin
      Next(P);
      if (Peek(P) = '?') then
      begin
        Next(P);
        if Peek(P) = ':' then
        begin
          Next(P);
          Result := NewNode(akGroup);
          Result^.Left := ParseAlternate(P);
        end
        else if (Peek(P) = 'P') or (Peek(P) = '<') then
        begin
          // Named group: (?P<name>...) or (?<name>...)
          if Peek(P) = 'P' then begin Next(P); Next(P); end  // skip P<
          else Next(P);  // skip <
          LName := '';
          while (Peek(P) <> '>') and (Peek(P) <> #0) do
            LName := LName + Next(P);
          if Peek(P) = '>' then Next(P);
          Result := NewNode(akCapture);
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
        Result := NewNode(akCapture);
        Result^.CaptureIndex := P.NumCaptures;
        Inc(P.NumCaptures);
        Result^.Left := ParseAlternate(P);
      end;
      if Peek(P) = ')' then Next(P)
      else
      begin
        RegexFreeAst(Result);
        Result := nil;
        raise ERegexCompileError.Create('unclosed group', P.Pos);
      end;
    end;
  else
    Next(P);
    Result := NewNode(akLiteral);
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
      rep := NewNode(akRepeat);
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
      if Peek(P) = '}' then Next(P);
      rep := NewNode(akRepeat);
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

  concat := NewNode(akConcat);
  concat^.Left := left;
  concat^.Right := right;

  while True do
  begin
    right := ParseRepeat(P);
    if right = nil then Break;
    left := concat;
    concat := NewNode(akConcat);
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
  alt := NewNode(akAlternate);
  alt^.Left := left;
  alt^.Right := right;
  Result := alt;
end;

function RegexParse(const APattern: string; out ANumCaptures: UInt32): PAstNode;
var P: TParser;
begin
  P.Pattern := APattern;
  P.Pos := 1;
  P.NumCaptures := 0;
  Result := ParseAlternate(P);
  ANumCaptures := P.NumCaptures;
end;

end.
