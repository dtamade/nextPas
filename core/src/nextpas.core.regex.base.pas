unit nextpas.core.regex.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.regex.charclass;

type
  TRegexFlags = set of (
    rfCaseInsensitive,
    rfMultiLine,
    rfDotAll
  );

  TOpCode = (
    opLiteral,
    opAnyChar,
    opCharClass,
    opSplit,
    opJump,
    opMatch,
    opSave,
    opAssert
  );

  TAssertKind = (
    akStart,
    akEnd,
    akWordBoundary,
    akNotWordBoundary
  );

  TInstruction = record
    Op: TOpCode;
    case Byte of
      0: (Ch: Byte);
      1: (ClassIdx: UInt16; Negated: Boolean);
      2: (X, Y: UInt32);
      3: (Target: UInt32);
      4: (Slot: UInt32);
      5: (Assert: TAssertKind);
  end;

  TGroupName = record
    Name: string;
    Index: UInt32;
  end;
  TGroupNameArray = array of TGroupName;

  TRegexProgram = record
    Code: array of TInstruction;
    Classes: array of TCharBitmap;
    GroupNames: TGroupNameArray;
    NumSlots: UInt32;
    NumCaptures: UInt32;
    LiteralPrefix: string;
    LiteralPrefixLen: SizeUInt;
    StartClass: TCharBitmap;
    StartClassSize: UInt32;
    Flags: TRegexFlags;
    IsPureLiteral: Boolean;
    IsLiteralAlt: Boolean;
    LiteralAltPatterns: array of string;
  end;

  TGroup = record
    Start: SizeInt;
    Len: SizeInt;
    function Value(const AInput: string): string;
    function Found: Boolean; inline;
  end;
  TGroupArray = array of TGroup;

  TMatch = record
    Start: SizeInt;
    Len: SizeInt;
    Groups: TGroupArray;
    function Found: Boolean; inline;
    function Value(const AInput: string): string;
  end;
  TMatchArray = array of TMatch;

  TReplaceFunc = function(const AInput: string; const AMatch: TMatch): string;

  ERegexError = class(Exception);
  ERegexCompileError = class(ERegexError)
  public
    Position: SizeUInt;
    constructor Create(const AMsg: string; APos: SizeUInt);
  end;

implementation

function TGroup.Value(const AInput: string): string;
begin
  if Start < 0 then Exit('');
  Result := Copy(AInput, Start + 1, Len);
end;

function TGroup.Found: Boolean;
begin
  Result := Start >= 0;
end;

function TMatch.Found: Boolean;
begin
  Result := Start >= 0;
end;

function TMatch.Value(const AInput: string): string;
begin
  if Start < 0 then Exit('');
  Result := Copy(AInput, Start + 1, Len);
end;

constructor ERegexCompileError.Create(const AMsg: string; APos: SizeUInt);
begin
  inherited CreateFmt('regex compile error at position %d: %s', [APos, AMsg]);
  Position := APos;
end;

end.
