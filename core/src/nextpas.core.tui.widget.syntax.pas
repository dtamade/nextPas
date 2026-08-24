unit nextpas.core.tui.widget.syntax;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses nextpas.core.tui.style, nextpas.core.tui.color, nextpas.core.tui.modifier;

type
  TTokenKind = (tkNormal, tkKeyword, tkString, tkComment, tkNumber, tkDirective, tkSymbol);

  PToken = ^TToken;
  TToken = record
    Start: Integer;
    Len: Integer;
    Kind: TTokenKind;
  end;

  TTokenArray = array of TToken;

  TLineState = packed record
    InBlockComment: Boolean;
    InString: Boolean;
    NestDepth: Byte;
    Reserved: Byte;
  end;

  TGetLineFunc = procedure(LineIndex: Integer; out P: PAnsiChar; out Len: Integer) of object;

  IHighlighter = interface
    function TokenizeLine(P: PAnsiChar; Len: Integer;
      const StateIn: TLineState; out StateOut: TLineState;
      Dst: PToken; MaxTokens: Integer): Integer;
    function LangId: AnsiString;
  end;

  TPascalHighlighter = class(TInterfacedObject, IHighlighter)
  public
    function TokenizeLine(P: PAnsiChar; Len: Integer;
      const StateIn: TLineState; out StateOut: TLineState;
      Dst: PToken; MaxTokens: Integer): Integer;
    function LangId: AnsiString;
  end;

  { PH33 P5c：JSON/TOML 高亮器（第二/第三语言，零 RTL）——语义自
    tui888.hl PH21 实战实现移植：JSON 键串后跟 ':' → tkKeyword 与值串
    区分；TOML '#' 注释、行首 [..]/[[..]] 表头 → tkDirective、词后跟
    '=' → 键；两语言共享数字（sign/int/frac/exp）与转义串扫描；无跨行
    结构（StateIn 恒等）；越界 MaxTokens 只计数不写入末尾 clamp }
  TJsonHighlighter = class(TInterfacedObject, IHighlighter)
  public
    function TokenizeLine(P: PAnsiChar; Len: Integer;
      const StateIn: TLineState; out StateOut: TLineState;
      Dst: PToken; MaxTokens: Integer): Integer;
    function LangId: AnsiString;
  end;

  TTomlHighlighter = class(TInterfacedObject, IHighlighter)
  public
    function TokenizeLine(P: PAnsiChar; Len: Integer;
      const StateIn: TLineState; out StateOut: TLineState;
      Dst: PToken; MaxTokens: Integer): Integer;
    function LangId: AnsiString;
  end;

  TSyntaxDoc = class
  private
    FHighlighter: IHighlighter;
    FLineCount: Integer;
    FLineStates: array of TLineState;
    FTokenPool: array of TToken;
    FTokenPoolUsed: Integer;
    FActiveTokenCount: Integer;
    FLineTokenOff: array of Integer;
    FLineTokenLen: array of Integer;
    FDirtyFrom: Integer;
    FGetLine: TGetLineFunc;
    procedure EnsurePoolCapacity(Extra: Integer);
    procedure Compact;
    procedure TokenizeLineInto(LineIdx: Integer; P: PAnsiChar; Len: Integer);
  public
    constructor Create(AHighlighter: IHighlighter; ALineCount: Integer;
      AGetLine: TGetLineFunc);
    procedure SetLineCount(ACount: Integer);
    procedure Invalidate(FromLine: Integer);
    procedure NotifyInsert(LineIndex, Count: Integer);
    procedure NotifyDelete(LineIndex, Count: Integer);
    procedure EnsureCleanTo(ToLine: Integer; MaxLines: Integer = 2000);
    procedure GetTokens(LineIndex: Integer; out Ptr: PToken; out Count: Integer);
    property LineCount: Integer read FLineCount;
  end;

  TSyntaxTheme = record
    Styles: array[TTokenKind] of TStyle;

    class function Default: TSyntaxTheme; static;
    class function Nord: TSyntaxTheme; static;
    function StyleFor(Kind: TTokenKind): TStyle; inline;
  end;

function TokenizePascal(const Line: AnsiString): TTokenArray;
function TokenizePascalStateful(const Line: AnsiString;
  const StateIn: TLineState; out StateOut: TLineState): TTokenArray;
function IsPascalKeyword(const W: AnsiString): Boolean;
function IsPascalKeywordP(P: PAnsiChar; Len: Integer): Boolean;

implementation

uses
  nextpas.core.text.grapheme;


{ Zero-allocation keyword hash table.
  128 slots, open addressing with linear probing (max probe = 2).
  Hash: (WordLen + (P[0] or $20) * 2 + (P[1] or $20) * 55) and $7F
  All keywords stored lowercase. Comparison is case-insensitive. }

const
  KW_TABLE_MASK = 127;
  KW_MAX_PROBE = 2;
  KW_MIN_LEN = 2;
  KW_MAX_LEN = 14;

type
  TKwSlot = packed record
    Len: Byte;
    W: array[0..13] of AnsiChar;
  end;

const
  KwTable: array[0..127] of TKwSlot = (
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('w','i','t','h',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('e','l','s','e',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len:14; W:('i','n','i','t','i','a','l','i','z','a','t','i','o','n')),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len:10; W:('d','e','s','t','r','u','c','t','o','r',#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('i','s',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('u','n','i','t',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('u','n','t','i','l',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('e','x','c','e','p','t',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 7; W:('e','x','p','o','r','t','s',#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('s','e','t',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('r','e','c','o','r','d',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('r','e','p','e','a','t',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('r','e','s','u','l','t',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('c','a','s','e',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('d','o',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('c','o','n','s','t',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('u','s','e','s',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('d','o','w','n','t','o',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('f','o','r',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len:11; W:('c','o','n','s','t','r','u','c','t','o','r',#0,#0,#0)),
    (Len: 4; W:('g','o','t','o',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('l','a','b','e','l',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('m','o','d',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('n','o','t',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('p','a','c','k','e','d',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('i','f',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('r','a','i','s','e',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('s','h','l',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('s','h','r',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('t','o',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('t','h','e','n',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('a','r','r','a','y',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('v','a','r',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('o','f',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len:14; W:('i','m','p','l','e','m','e','n','t','a','t','i','o','n')),
    (Len: 5; W:('w','h','i','l','e',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('x','o','r',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('d','i','v',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('o','r',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('f','i','l','e',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 7; W:('f','i','n','a','l','l','y',#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 7; W:('p','r','o','g','r','a','m',#0,#0,#0,#0,#0,#0,#0)),
    (Len: 8; W:('p','r','o','p','e','r','t','y',#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('a','n','d',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len:12; W:('f','i','n','a','l','i','z','a','t','i','o','n',#0,#0)),
    (Len: 9; W:('p','r','o','c','e','d','u','r','e',#0,#0,#0,#0,#0)),
    (Len: 3; W:('t','r','y',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 4; W:('t','y','p','e',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 7; W:('l','i','b','r','a','r','y',#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('e','n','d',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('n','i','l',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('o','b','j','e','c','t',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 0; W:(#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('i','n',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 8; W:('f','u','n','c','t','i','o','n',#0,#0,#0,#0,#0,#0)),
    (Len: 8; W:('o','p','e','r','a','t','o','r',#0,#0,#0,#0,#0,#0)),
    (Len: 2; W:('a','s',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 3; W:('a','s','m',#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 6; W:('i','n','l','i','n','e',#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 5; W:('b','e','g','i','n',#0,#0,#0,#0,#0,#0,#0,#0,#0)),
    (Len: 9; W:('i','n','h','e','r','i','t','e','d',#0,#0,#0,#0,#0)),
    (Len: 9; W:('i','n','t','e','r','f','a','c','e',#0,#0,#0,#0,#0)),
    (Len: 5; W:('c','l','a','s','s',#0,#0,#0,#0,#0,#0,#0,#0,#0))
  );

function IsPascalKeywordP(P: PAnsiChar; Len: Integer): Boolean;
var
  H, Probe: Integer;
  Slot: ^TKwSlot;
  J: Integer;
  C1, C2: Byte;
begin
  if (Len < KW_MIN_LEN) or (Len > KW_MAX_LEN) then Exit(False);

  C1 := Byte(P[0]) or $20;
  C2 := Byte(P[1]) or $20;
  H := (Len + Integer(C1) * 2 + Integer(C2) * 55) and KW_TABLE_MASK;

  for Probe := 0 to KW_MAX_PROBE do
  begin
    Slot := @KwTable[H];
    if Slot^.Len = 0 then Exit(False);
    if Slot^.Len = Len then
    begin
      J := 0;
      while (J < Len) and ((Byte(P[J]) or $20) = Byte(Slot^.W[J])) do Inc(J);
      if J = Len then Exit(True);
    end;
    H := (H + 1) and KW_TABLE_MASK;
  end;
  Result := False;
end;

function IsPascalKeyword(const W: AnsiString): Boolean;
begin
  if System.Length(W) = 0 then Exit(False);
  Result := IsPascalKeywordP(@W[1], System.Length(W));
end;

function IsAlpha(C: Char): Boolean; inline;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '_']);
end;

function IsAlNum(C: Char): Boolean; inline;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsDigit(C: Char): Boolean; inline;
begin
  Result := C in ['0'..'9'];
end;

function TokenizePascal(const Line: AnsiString): TTokenArray;
var
  Tokens: array of TToken;
  Count, I, Start, Len: Integer;

  procedure AddToken(AStart, ALen: Integer; AKind: TTokenKind);
  begin
    Inc(Count);
    SetLength(Tokens, Count);
    Tokens[Count - 1].Start := AStart;
    Tokens[Count - 1].Len := ALen;
    Tokens[Count - 1].Kind := AKind;
  end;

begin
  Count := 0;
  Tokens := nil;
  Len := Length(Line);
  I := 1;

  while I <= Len do
  begin
    // Whitespace
    if Line[I] = ' ' then
    begin
      Start := I;
      while (I <= Len) and (Line[I] = ' ') do Inc(I);
      AddToken(Start, I - Start, tkNormal);
    end
    // Directive {$...}
    else if (Line[I] = '{') and (I < Len) and (Line[I + 1] = '$') then
    begin
      Start := I;
      while (I <= Len) and (Line[I] <> '}') do Inc(I);
      if I <= Len then Inc(I);
      AddToken(Start, I - Start, tkDirective);
    end
    // Comment { }
    else if Line[I] = '{' then
    begin
      Start := I;
      while (I <= Len) and (Line[I] <> '}') do Inc(I);
      if I <= Len then Inc(I);
      AddToken(Start, I - Start, tkComment);
    end
    // Line comment //
    else if (Line[I] = '/') and (I < Len) and (Line[I + 1] = '/') then
    begin
      AddToken(I, Len - I + 1, tkComment);
      I := Len + 1;
    end
    // String literal
    else if Line[I] = '''' then
    begin
      Start := I;
      Inc(I);
      while I <= Len do
      begin
        if Line[I] = '''' then
        begin
          Inc(I);
          if (I <= Len) and (Line[I] = '''') then
            Inc(I)
          else
            Break;
        end
        else
          Inc(I);
      end;
      AddToken(Start, I - Start, tkString);
    end
    // Number
    else if IsDigit(Line[I]) or ((Line[I] = '$') and (I < Len) and (Line[I+1] in ['0'..'9','A'..'F','a'..'f'])) then
    begin
      Start := I;
      if Line[I] = '$' then
      begin
        Inc(I);
        while (I <= Len) and (Line[I] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(I);
      end
      else
      begin
        while (I <= Len) and (IsDigit(Line[I]) or (Line[I] = '.')) do Inc(I);
      end;
      AddToken(Start, I - Start, tkNumber);
    end
    // Identifier or keyword
    else if IsAlpha(Line[I]) then
    begin
      Start := I;
      while (I <= Len) and IsAlNum(Line[I]) do Inc(I);
      if IsPascalKeywordP(@Line[Start], I - Start) then
        AddToken(Start, I - Start, tkKeyword)
      else
        AddToken(Start, I - Start, tkNormal);
    end
    // Symbol
    else
    begin
      AddToken(I, 1, tkSymbol);
      Inc(I);
    end;
  end;

  Result := Tokens;
end;

{ TSyntaxTheme }

class function TSyntaxTheme.Default: TSyntaxTheme;
begin
  Result.Styles[tkNormal] := TStyle.Default;
  Result.Styles[tkKeyword] := TStyle.Default.WithFg(TUI_YELLOW).WithModifier([mbBold]);
  Result.Styles[tkString] := TStyle.Default.WithFg(TUI_GREEN);
  Result.Styles[tkComment] := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.Styles[tkNumber] := TStyle.Default.WithFg(TUI_CYAN);
  Result.Styles[tkDirective] := TStyle.Default.WithFg(TUI_MAGENTA);
  Result.Styles[tkSymbol] := TStyle.Default.WithFg(TUI_WHITE);
end;

class function TSyntaxTheme.Nord: TSyntaxTheme;
begin
  Result.Styles[tkNormal] := TStyle.Default.WithFg(RgbColor(216, 222, 233));
  Result.Styles[tkKeyword] := TStyle.Default.WithFg(RgbColor(129, 161, 193)).WithModifier([mbBold]);
  Result.Styles[tkString] := TStyle.Default.WithFg(RgbColor(163, 190, 140));
  Result.Styles[tkComment] := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.Styles[tkNumber] := TStyle.Default.WithFg(RgbColor(180, 142, 173));
  Result.Styles[tkDirective] := TStyle.Default.WithFg(RgbColor(235, 203, 139));
  Result.Styles[tkSymbol] := TStyle.Default.WithFg(RgbColor(236, 239, 244));
end;

function TSyntaxTheme.StyleFor(Kind: TTokenKind): TStyle;
begin
  Result := Styles[Kind];
end;

{ TSyntaxDoc }

const
  INITIAL_POOL_PER_LINE = 32;
  MAX_TOKENS_PER_LINE = 4096;

constructor TSyntaxDoc.Create(AHighlighter: IHighlighter; ALineCount: Integer;
  AGetLine: TGetLineFunc);
var Cap: Integer;
begin
  inherited Create;
  FHighlighter := AHighlighter;
  FGetLine := AGetLine;
  FLineCount := ALineCount;
  SetLength(FLineStates, ALineCount + 1);
  FillChar(FLineStates[0], (ALineCount + 1) * SizeOf(TLineState), 0);
  SetLength(FLineTokenOff, ALineCount);
  SetLength(FLineTokenLen, ALineCount);
  FillChar(FLineTokenOff[0], ALineCount * SizeOf(Integer), 0);
  FillChar(FLineTokenLen[0], ALineCount * SizeOf(Integer), 0);
  Cap := ALineCount * INITIAL_POOL_PER_LINE;
  if Cap < 256 then Cap := 256;
  SetLength(FTokenPool, Cap);
  FTokenPoolUsed := 0;
  FActiveTokenCount := 0;
  FDirtyFrom := 0;
end;

procedure TSyntaxDoc.SetLineCount(ACount: Integer);
begin
  if ACount = FLineCount then Exit;
  FLineCount := ACount;
  SetLength(FLineStates, ACount + 1);
  SetLength(FLineTokenOff, ACount);
  SetLength(FLineTokenLen, ACount);
  if FDirtyFrom > ACount then FDirtyFrom := ACount;
end;

procedure TSyntaxDoc.Invalidate(FromLine: Integer);
begin
  if FromLine < FDirtyFrom then FDirtyFrom := FromLine;
end;

procedure TSyntaxDoc.NotifyInsert(LineIndex, Count: Integer);
var I: Integer;
begin
  FLineCount := FLineCount + Count;
  SetLength(FLineStates, FLineCount + 1);
  SetLength(FLineTokenOff, FLineCount);
  SetLength(FLineTokenLen, FLineCount);
  for I := FLineCount - 1 downto LineIndex + Count do
  begin
    FLineStates[I + 1] := FLineStates[I - Count + 1];
    FLineTokenOff[I] := FLineTokenOff[I - Count];
    FLineTokenLen[I] := FLineTokenLen[I - Count];
  end;
  for I := LineIndex to LineIndex + Count - 1 do
    FLineTokenLen[I] := 0;
  if LineIndex < FDirtyFrom then FDirtyFrom := LineIndex;
end;

procedure TSyntaxDoc.NotifyDelete(LineIndex, Count: Integer);
var I: Integer;
begin
  for I := LineIndex to FLineCount - Count - 1 do
  begin
    FLineStates[I + 1] := FLineStates[I + Count + 1];
    FLineTokenOff[I] := FLineTokenOff[I + Count];
    FLineTokenLen[I] := FLineTokenLen[I + Count];
  end;
  FLineCount := FLineCount - Count;
  SetLength(FLineStates, FLineCount + 1);
  SetLength(FLineTokenOff, FLineCount);
  SetLength(FLineTokenLen, FLineCount);
  if LineIndex < FDirtyFrom then FDirtyFrom := LineIndex;
end;

procedure TSyntaxDoc.EnsurePoolCapacity(Extra: Integer);
var Cap: Integer;
begin
  Cap := System.Length(FTokenPool);
  if FTokenPoolUsed + Extra <= Cap then Exit;
  if FActiveTokenCount * 2 < FTokenPoolUsed then
  begin
    Compact;
    if FTokenPoolUsed + Extra <= Cap then Exit;
  end;
  while Cap < FTokenPoolUsed + Extra do
    Cap := Cap * 2;
  SetLength(FTokenPool, Cap);
end;

procedure TSyntaxDoc.Compact;
var I, WritePos: Integer;
begin
  WritePos := 0;
  for I := 0 to FLineCount - 1 do
  begin
    if FLineTokenLen[I] > 0 then
      Move(FTokenPool[FLineTokenOff[I]], FTokenPool[WritePos],
        FLineTokenLen[I] * SizeOf(TToken));
    FLineTokenOff[I] := WritePos;
    Inc(WritePos, FLineTokenLen[I]);
  end;
  FTokenPoolUsed := WritePos;
end;

procedure TSyntaxDoc.TokenizeLineInto(LineIdx: Integer; P: PAnsiChar; Len: Integer);
var
  StateOut: TLineState;
  Count: Integer;
begin
  Dec(FActiveTokenCount, FLineTokenLen[LineIdx]);
  EnsurePoolCapacity(MAX_TOKENS_PER_LINE);
  Count := FHighlighter.TokenizeLine(P, Len, FLineStates[LineIdx], StateOut,
    @FTokenPool[FTokenPoolUsed], MAX_TOKENS_PER_LINE);
  FLineTokenOff[LineIdx] := FTokenPoolUsed;
  FLineTokenLen[LineIdx] := Count;
  Inc(FTokenPoolUsed, Count);
  Inc(FActiveTokenCount, Count);
  FLineStates[LineIdx + 1] := StateOut;
end;

procedure TSyntaxDoc.EnsureCleanTo(ToLine: Integer; MaxLines: Integer);
var
  P: PAnsiChar;
  Len: Integer;
  OldState: TLineState;
  Processed: Integer;
begin
  if FDirtyFrom > ToLine then Exit;
  Processed := 0;

  while (FDirtyFrom <= ToLine) and (Processed < MaxLines) do
  begin
    if FDirtyFrom >= FLineCount then
    begin
      FDirtyFrom := High(Integer);
      Exit;
    end;
    OldState := FLineStates[FDirtyFrom + 1];
    FGetLine(FDirtyFrom, P, Len);
    TokenizeLineInto(FDirtyFrom, P, Len);
    Inc(FDirtyFrom);
    Inc(Processed);
    if (FDirtyFrom > ToLine) and (FDirtyFrom <= FLineCount) and
       (CompareByte(FLineStates[FDirtyFrom], OldState, SizeOf(TLineState)) = 0) then
    begin
      FDirtyFrom := High(Integer);
      Exit;
    end;
  end;
  if FDirtyFrom > ToLine then
    FDirtyFrom := High(Integer);
end;

procedure TSyntaxDoc.GetTokens(LineIndex: Integer; out Ptr: PToken; out Count: Integer);
begin
  EnsureCleanTo(LineIndex);
  Ptr := @FTokenPool[FLineTokenOff[LineIndex]];
  Count := FLineTokenLen[LineIndex];
end;

{ TokenizePascalStateful }

function TokenizePascalStateful(const Line: AnsiString;
  const StateIn: TLineState; out StateOut: TLineState): TTokenArray;
var
  Tokens: array of TToken;
  Count, I, Start, Len: Integer;
  LGR: TGraphemeResult;

  procedure AddToken(AStart, ALen: Integer; AKind: TTokenKind);
  begin
    Inc(Count);
    if Count > System.Length(Tokens) then
      SetLength(Tokens, Count * 2);
    Tokens[Count - 1].Start := AStart;
    Tokens[Count - 1].Len := ALen;
    Tokens[Count - 1].Kind := AKind;
  end;

begin
  StateOut := StateIn;
  Count := 0;
  SetLength(Tokens, 16);
  Len := System.Length(Line);
  I := 1;

  while I <= Len do
  begin
    if StateOut.InBlockComment then
    begin
      Start := I;
      while I <= Len do
      begin
        if (Line[I] = '}') then begin StateOut.InBlockComment := False; Inc(I); Break; end;
        if (I < Len) and (Line[I] = '*') and (Line[I+1] = ')') then
          begin StateOut.InBlockComment := False; Inc(I, 2); Break; end;
        Inc(I);
      end;
      AddToken(Start, I - Start, tkComment);
      Continue;
    end;

    if Line[I] = '{' then
    begin
      Start := I;
      if (I < Len) and (Line[I+1] = '$') then
      begin
        while (I <= Len) and (Line[I] <> '}') do Inc(I);
        if I <= Len then Inc(I);
        AddToken(Start, I - Start, tkDirective);
      end
      else
      begin
        StateOut.InBlockComment := True;
        while I <= Len do
        begin
          if Line[I] = '}' then begin StateOut.InBlockComment := False; Inc(I); Break; end;
          Inc(I);
        end;
        AddToken(Start, I - Start, tkComment);
      end;
      Continue;
    end;

    if (I < Len) and (Line[I] = '(') and (Line[I+1] = '*') then
    begin
      Start := I;
      Inc(I, 2);
      StateOut.InBlockComment := True;
      while I <= Len do
      begin
        if (I < Len) and (Line[I] = '*') and (Line[I+1] = ')') then
          begin StateOut.InBlockComment := False; Inc(I, 2); Break; end;
        Inc(I);
      end;
      AddToken(Start, I - Start, tkComment);
      Continue;
    end;

    if (Line[I] = '/') and (I < Len) and (Line[I+1] = '/') then
    begin
      AddToken(I, Len - I + 1, tkComment);
      I := Len + 1;
      Continue;
    end;

    if Line[I] = '''' then
    begin
      Start := I; Inc(I);
      while I <= Len do
      begin
        if Line[I] = '''' then begin Inc(I); Break; end;
        Inc(I);
      end;
      AddToken(Start, I - Start, tkString);
      Continue;
    end;

    if Line[I] in ['A'..'Z', 'a'..'z', '_'] then
    begin
      Start := I;
      while (I <= Len) and (Line[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(I);
      if IsPascalKeywordP(@Line[Start], I - Start) then
        AddToken(Start, I - Start, tkKeyword)
      else
        AddToken(Start, I - Start, tkNormal);
      Continue;
    end;

    if Line[I] in ['0'..'9'] then
    begin
      Start := I;
      while (I <= Len) and (Line[I] in ['0'..'9', '.', '$']) do Inc(I);
      AddToken(Start, I - Start, tkNumber);
      Continue;
    end;

    if Line[I] in ['+', '-', '*', '/', '=', '<', '>', '.', ',', ';', ':', '(', ')', '[', ']', '@', '^'] then
    begin
      AddToken(I, 1, tkSymbol);
      Inc(I);
      Continue;
    end;

    { 高位字节按完整 UTF-8 图素发一个 token（逐字节拆 token 会让 CJK
      渲染成单字节乱码格——PH33 P5a）；ASCII 兜底仍逐字符 }
    if Ord(Line[I]) >= $80 then
    begin
      LGR := GraphemeNext(PByte(@Line[I]), SizeUInt(Len - I + 1));
      AddToken(I, LGR.ByteLen, tkNormal);
      Inc(I, LGR.ByteLen);
    end
    else
    begin
      AddToken(I, 1, tkNormal);
      Inc(I);
    end;
  end;

  SetLength(Tokens, Count);
  Result := Tokens;
end;

{ TPascalHighlighter }

function TPascalHighlighter.TokenizeLine(P: PAnsiChar; Len: Integer;
  const StateIn: TLineState; out StateOut: TLineState;
  Dst: PToken; MaxTokens: Integer): Integer;
var
  Count, I, Start: Integer;
  LGR: TGraphemeResult;

  procedure Emit(AStart, ALen: Integer; AKind: TTokenKind); inline;
  begin
    if Count < MaxTokens then
    begin
      Dst[Count].Start := AStart;
      Dst[Count].Len := ALen;
      Dst[Count].Kind := AKind;
    end;
    Inc(Count);
  end;

  function Ch(Idx: Integer): AnsiChar; inline;
  begin
    Result := P[Idx - 1];
  end;

begin
  StateOut := StateIn;
  Count := 0;
  I := 1;

  while I <= Len do
  begin
    if StateOut.InBlockComment then
    begin
      Start := I;
      while I <= Len do
      begin
        if Ch(I) = '}' then begin StateOut.InBlockComment := False; Inc(I); Break; end;
        if (I < Len) and (Ch(I) = '*') and (Ch(I+1) = ')') then
          begin StateOut.InBlockComment := False; Inc(I, 2); Break; end;
        Inc(I);
      end;
      Emit(Start, I - Start, tkComment);
      Continue;
    end;

    if Ch(I) = '{' then
    begin
      Start := I;
      if (I < Len) and (Ch(I+1) = '$') then
      begin
        while (I <= Len) and (Ch(I) <> '}') do Inc(I);
        if I <= Len then Inc(I);
        Emit(Start, I - Start, tkDirective);
      end
      else
      begin
        StateOut.InBlockComment := True;
        while I <= Len do
        begin
          if Ch(I) = '}' then begin StateOut.InBlockComment := False; Inc(I); Break; end;
          Inc(I);
        end;
        Emit(Start, I - Start, tkComment);
      end;
      Continue;
    end;

    if (I < Len) and (Ch(I) = '(') and (Ch(I+1) = '*') then
    begin
      Start := I; Inc(I, 2);
      StateOut.InBlockComment := True;
      while I <= Len do
      begin
        if (I < Len) and (Ch(I) = '*') and (Ch(I+1) = ')') then
          begin StateOut.InBlockComment := False; Inc(I, 2); Break; end;
        Inc(I);
      end;
      Emit(Start, I - Start, tkComment);
      Continue;
    end;

    if (Ch(I) = '/') and (I < Len) and (Ch(I+1) = '/') then
    begin
      Emit(I, Len - I + 1, tkComment);
      I := Len + 1;
      Continue;
    end;

    if Ch(I) = '''' then
    begin
      Start := I; Inc(I);
      while I <= Len do
      begin
        if Ch(I) = '''' then begin Inc(I); Break; end;
        Inc(I);
      end;
      Emit(Start, I - Start, tkString);
      Continue;
    end;

    if Ch(I) in ['A'..'Z', 'a'..'z', '_'] then
    begin
      Start := I;
      while (I <= Len) and (Ch(I) in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(I);
      if IsPascalKeywordP(@P[Start - 1], I - Start) then
        Emit(Start, I - Start, tkKeyword)
      else
        Emit(Start, I - Start, tkNormal);
      Continue;
    end;

    if Ch(I) in ['0'..'9'] then
    begin
      Start := I;
      while (I <= Len) and (Ch(I) in ['0'..'9', '.', '$']) do Inc(I);
      Emit(Start, I - Start, tkNumber);
      Continue;
    end;

    if Ch(I) in ['+', '-', '*', '/', '=', '<', '>', '.', ',', ';', ':', '(', ')', '[', ']', '@', '^'] then
    begin
      Emit(I, 1, tkSymbol);
      Inc(I);
      Continue;
    end;

    { 同 TokenizePascalStateful：高位字节按完整图素发 token（PH33 P5a） }
    if Ord(Ch(I)) >= $80 then
    begin
      LGR := GraphemeNext(PByte(P) + (I - 1), SizeUInt(Len - I + 1));
      Emit(I, LGR.ByteLen, tkNormal);
      Inc(I, LGR.ByteLen);
    end
    else
    begin
      Emit(I, 1, tkNormal);
      Inc(I);
    end;
  end;

  if Count > MaxTokens then Count := MaxTokens;
  Result := Count;
end;

function TPascalHighlighter.LangId: AnsiString;
begin
  Result := 'pascal';
end;

{ ===== PH33 P5c：JSON/TOML 高亮器（语义自 tui888.hl PH21 移植，零 RTL）===== }

type
  TCfgDialect = (cdJson, cdToml);

procedure CfgEmit(Dst: PToken; Max: Integer; var Count: Integer;
  AStart, ALen: Integer; AKind: TTokenKind);
begin
  if Count < Max then
  begin
    Dst[Count].Start := AStart;
    Dst[Count].Len := ALen;
    Dst[Count].Kind := AKind;
  end;
  Inc(Count);
end;

{ 扫描 quoted string：Idx 指向开引号（1-based）。返回闭引号位置；未闭合
  返回 0。`\` 与其后一字符整体跳过，行尾 `\` 视为未闭合 }
function CfgScanString(P: PAnsiChar; Len, Idx: Integer): Integer;
var LI: Integer; LC: AnsiChar;
begin
  LI := Idx + 1;
  while LI <= Len do
  begin
    LC := P[LI - 1];
    if LC = '"' then Exit(LI);
    if LC = '\' then
    begin
      Inc(LI, 2);
      if LI > Len then Exit(0);
    end
    else
      Inc(LI);
  end;
  Result := 0;
end;

{ 数字段（sign/int/frac/exp）：返回段后 one-past 下标 }
function CfgScanNumber(P: PAnsiChar; Len, Idx: Integer): Integer;
var LI: Integer;
begin
  LI := Idx;
  if (LI <= Len) and (P[LI - 1] in ['-', '+']) then Inc(LI);
  while (LI <= Len) and (P[LI - 1] in ['0'..'9']) do Inc(LI);
  if (LI <= Len) and (P[LI - 1] = '.') then
  begin
    Inc(LI);
    while (LI <= Len) and (P[LI - 1] in ['0'..'9']) do Inc(LI);
  end;
  if (LI <= Len) and (P[LI - 1] in ['e', 'E']) then
  begin
    Inc(LI);
    if (LI <= Len) and (P[LI - 1] in ['-', '+']) then Inc(LI);
    while (LI <= Len) and (P[LI - 1] in ['0'..'9']) do Inc(LI);
  end;
  Result := LI;
end;

{ 词字节：字母数字下划线 + UTF-8 高字节（CJK 键名成词） }
function CfgIsWordByte(B: Byte): Boolean;
begin
  Result := (B in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'), Ord('0')..Ord('9')])
    or (B = Ord('_')) or (B >= 128);
end;

{ 自 AFrom 起跳过空白后的字符（越界返 #0） }
function CfgPeekNonSpace(P: PAnsiChar; Len, AFrom: Integer): AnsiChar;
var LI: Integer;
begin
  LI := AFrom;
  while (LI <= Len) and (P[LI - 1] in [' ', #9]) do Inc(LI);
  if LI > Len then Result := #0 else Result := P[LI - 1];
end;

function CfgWordIs(const P: PAnsiChar; AStart, AEnd_: Integer;
  const AW: AnsiString): Boolean;
var I, LLen: Integer;
begin
  LLen := AEnd_ - AStart;
  Result := LLen = Length(AW);
  if not Result then Exit;
  for I := 0 to LLen - 1 do
    if P[AStart - 1 + I] <> AW[I + 1] then Exit(False);
end;

{ 整词字面量 true/false/null }
function CfgIsLiteralWord(P: PAnsiChar; AStart, AEnd_: Integer): Boolean;
begin
  Result := CfgWordIs(P, AStart, AEnd_, 'true') or
    CfgWordIs(P, AStart, AEnd_, 'false') or
    CfgWordIs(P, AStart, AEnd_, 'null');
end;

{ 主扫描：无跨行结构 → StateIn 恒等；返回实际写入数，越界只计数末尾 clamp }
function CfgTokenizeLine(ADialect: TCfgDialect; P: PAnsiChar; Len: Integer;
  const StateIn: TLineState; out StateOut: TLineState;
  Dst: PToken; MaxTokens: Integer): Integer;
var
  LCount, LI, LStart, LEndI: Integer;
  LC, LNext: AnsiChar;
  LKind: TTokenKind;
  LAtLineHead: Boolean;
begin
  StateOut := StateIn;
  LCount := 0;
  LI := 1;
  LAtLineHead := True;
  while LI <= Len do
  begin
    LC := P[LI - 1];

    if (LC = ' ') or (LC = #9) then begin Inc(LI); Continue; end;

    { TOML '#' 注释到行尾；JSON 无注释 }
    if (ADialect = cdToml) and (LC = '#') then
    begin
      CfgEmit(Dst, MaxTokens, LCount, LI, Len - LI + 1, tkComment);
      Break;
    end;

    { 字符串（转义 `\` 跳）；JSON 键串后跟 ':' → tkKeyword 与值串区分 }
    if LC = '"' then
    begin
      LEndI := CfgScanString(P, Len, LI);
      if LEndI = 0 then LEndI := Len + 1
      else Inc(LEndI);
      LKind := tkString;
      if (ADialect = cdJson) and (CfgPeekNonSpace(P, Len, LEndI) = ':') then
        LKind := tkKeyword;
      CfgEmit(Dst, MaxTokens, LCount, LI, LEndI - LI, LKind);
      LI := LEndI;
      LAtLineHead := False;
      Continue;
    end;

    { 数字：int/float/exp，含前导 +/- 紧贴数字的判定 }
    if (LC in ['0'..'9']) or
      ((LC in ['-', '+']) and (LI < Len) and (P[LI] in ['0'..'9'])) then
    begin
      LStart := LI;
      LI := CfgScanNumber(P, Len, LI);
      CfgEmit(Dst, MaxTokens, LCount, LStart, LI - LStart, tkNumber);
      LAtLineHead := False;
      Continue;
    end;

    { TOML 表头：行首 [ 起（含 [[ 数组表），扫到闭 ]（双闭并入）→ tkDirective }
    if (ADialect = cdToml) and LAtLineHead and (LC = '[') then
    begin
      LStart := LI;
      while (LI <= Len) and (P[LI - 1] <> ']') do Inc(LI);
      if LI <= Len then Inc(LI);
      if (LI <= Len) and (P[LI - 1] = ']') then Inc(LI);
      CfgEmit(Dst, MaxTokens, LCount, LStart, LI - LStart, tkDirective);
      LAtLineHead := False;
      Continue;
    end;

    { 符号 }
    case ADialect of
      cdJson:
        if LC in ['{', '}', '[', ']', ':', ','] then
        begin
          CfgEmit(Dst, MaxTokens, LCount, LI, 1, tkSymbol);
          Inc(LI); LAtLineHead := False; Continue;
        end;
      cdToml:
        if LC in ['[', ']', '=', ','] then
        begin
          CfgEmit(Dst, MaxTokens, LCount, LI, 1, tkSymbol);
          Inc(LI); LAtLineHead := False; Continue;
        end;
    end;

    { 词：字面量 → tkKeyword；TOML 词后跟 '=' → 键 tkKeyword }
    if CfgIsWordByte(Byte(LC)) then
    begin
      LStart := LI;
      while (LI <= Len) and CfgIsWordByte(Byte(P[LI - 1])) do Inc(LI);
      LKind := tkNormal;
      if CfgIsLiteralWord(P, LStart, LI) then LKind := tkKeyword
      else if ADialect = cdToml then
      begin
        LNext := CfgPeekNonSpace(P, Len, LI);
        if LNext = '=' then LKind := tkKeyword;
      end;
      CfgEmit(Dst, MaxTokens, LCount, LStart, LI - LStart, LKind);
      LAtLineHead := False;
      Continue;
    end;

    { 其余可见字符合并连续 run → tkNormal }
    LStart := LI;
    Inc(LI);
    while (LI <= Len) and not CfgIsWordByte(Byte(P[LI - 1]))
      and not (P[LI - 1] in ['"', '#', ':', '=', ',', '[', ']', '{', '}'])
      and not (P[LI - 1] in ['0'..'9']) and (P[LI - 1] <> ' ')
      and (P[LI - 1] <> #9) do
      Inc(LI);
    CfgEmit(Dst, MaxTokens, LCount, LStart, LI - LStart, tkNormal);
    LAtLineHead := False;
  end;

  if LCount > MaxTokens then LCount := MaxTokens;
  Result := LCount;
end;

function TJsonHighlighter.TokenizeLine(P: PAnsiChar; Len: Integer;
  const StateIn: TLineState; out StateOut: TLineState;
  Dst: PToken; MaxTokens: Integer): Integer;
begin
  Result := CfgTokenizeLine(cdJson, P, Len, StateIn, StateOut, Dst, MaxTokens);
end;

function TJsonHighlighter.LangId: AnsiString;
begin
  Result := 'json';
end;

function TTomlHighlighter.TokenizeLine(P: PAnsiChar; Len: Integer;
  const StateIn: TLineState; out StateOut: TLineState;
  Dst: PToken; MaxTokens: Integer): Integer;
begin
  Result := CfgTokenizeLine(cdToml, P, Len, StateIn, StateOut, Dst, MaxTokens);
end;

function TTomlHighlighter.LangId: AnsiString;
begin
  Result := 'toml';
end;

end.
