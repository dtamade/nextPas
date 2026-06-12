unit nextpas.core.json.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

const
  JNF_CLEAN_STR = 1;

type
  TJsonNodeKind = (
    jnkNull,
    jnkBool,
    jnkInt,
    jnkReal,
    jnkString,
    jnkArray,
    jnkObject
  );

  TJsonNode = record
    Kind: TJsonNodeKind;
    Flags: Byte;
    Next: UInt32;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (RealVal: Double);
      3: (Str: TStringView);
      4: (Container: record
            FirstChild: UInt32;
            Count: UInt32;
          end);
  end;
  PJsonNode = ^TJsonNode;

  TJsonTokenKind = (
    jtkNone,
    jtkBeginObject,
    jtkEndObject,
    jtkBeginArray,
    jtkEndArray,
    jtkKey,
    jtkString,
    jtkInt,
    jtkFloat,
    jtkBool,
    jtkNull,
    jtkError
  );

  TJsonError = record
    Message: TStringView;
    Offset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;

const
  JSON_NODE_NONE = UInt32($FFFFFFFF);
  JSON_OBJECT_HASH_THRESHOLD = 16;

procedure JsonErrorSetPosition(var AError: TJsonError; const AInput: TStringView;
  AOffset: SizeUInt);

implementation

procedure JsonErrorSetPosition(var AError: TJsonError; const AInput: TStringView;
  AOffset: SizeUInt);
var
  LIdx, LStop: SizeUInt;
  LLine, LColumn: UInt32;
begin
  AError.Offset := AOffset;
  if AOffset > AInput.Len then
    LStop := AInput.Len
  else
    LStop := AOffset;

  LIdx := 0;
  LLine := 1;
  LColumn := 1;
  while LIdx < LStop do
  begin
    case AInput.Data[LIdx] of
      #10:
      begin
        Inc(LLine);
        LColumn := 1;
      end;
      #13:
      begin
        Inc(LLine);
        LColumn := 1;
        if (LIdx + 1 < LStop) and (AInput.Data[LIdx + 1] = #10) then
          Inc(LIdx);
      end;
    else
      Inc(LColumn);
    end;
    Inc(LIdx);
  end;

  AError.Line := LLine;
  AError.Column := LColumn;
end;

end.
