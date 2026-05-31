unit nextpas.core.tui.event;

{**
 * @desc 输入事件类型——TTerminal.PollEvent 产出这些。
 *
 * 鼠标模型：mkDown/mkUp/mkMoved/mkDrag/mkScrollUp/mkScrollDown，
 * 全部携带 0-based cell 坐标、按钮、修饰键。
 *
 * 键盘模型：17 个 TKeyCodeKind + UCS-4 码点（kcChar）。
 * 支持 CSI u (kitty protocol) 区分 Shift+Enter 等。
 *
 * Resize：SIGWINCH 后投递；buffer 已由 TTerminal 调整完毕。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

type
  TEventKind = (evNone, evKey, evMouse, evResize);

  TKeyCodeKind = (
    kcChar, kcEnter, kcEsc, kcTab, kcBackTab, kcBackspace, kcDelete,
    kcLeft, kcRight, kcUp, kcDown,
    kcHome, kcEnd, kcPageUp, kcPageDown,
    kcInsert, kcF
  );

  TKeyModifier = (kmCtrl, kmAlt, kmShift);
  TKeyModifiers = set of TKeyModifier;

  TKeyEvent = packed record
    Code: TKeyCodeKind;
    Ch: LongWord;          { kcChar 时为 UCS-4 码点 }
    F: Byte;               { kcF 时为 1..12 }
    Modifiers: TKeyModifiers;
  end;

  TMouseEventKind = (mkDown, mkUp, mkMoved, mkDrag, mkScrollUp, mkScrollDown);
  TMouseButton = (mbLeft, mbMiddle, mbRight, mbNone);

  TMouseEvent = packed record
    Kind: TMouseEventKind;
    Button: TMouseButton;
    X, Y: Word;
    Modifiers: TKeyModifiers;
  end;

  TResizeEvent = packed record
    Width, Height: Word;
  end;

  TEvent = record
    Kind: TEventKind;
    case Byte of
      0: (Key: TKeyEvent);
      1: (Mouse: TMouseEvent);
      2: (Resize: TResizeEvent);
  end;

function NoneEvent: TEvent; inline;
function KeyCharEvent(ACh: LongWord; AMods: TKeyModifiers): TEvent;
function KeyCodeEvent(ACode: TKeyCodeKind; AMods: TKeyModifiers): TEvent;
function KeyFunctionEvent(AF: Byte; AMods: TKeyModifiers): TEvent;
function MouseEvent(AKind: TMouseEventKind; ABtn: TMouseButton;
  AX, AY: Word; AMods: TKeyModifiers): TEvent;
function ResizeEvent(AWidth, AHeight: Word): TEvent;

{ TEvent 便利判断——简化消费方的 case 分派 }
function IsNone(const AEv: TEvent): Boolean; inline;
function IsKey(const AEv: TEvent): Boolean; inline;
function IsMouse(const AEv: TEvent): Boolean; inline;
function IsResize(const AEv: TEvent): Boolean; inline;
function IsKeyChar(const AEv: TEvent; ACh: LongWord): Boolean; inline;
function IsKeyCode(const AEv: TEvent; ACode: TKeyCodeKind): Boolean; inline;
function IsQuit(const AEv: TEvent): Boolean; inline;

implementation

function NoneEvent: TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evNone;
end;

function KeyCharEvent(ACh: LongWord; AMods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := kcChar;
  Result.Key.Ch := ACh;
  Result.Key.Modifiers := AMods;
end;

function KeyCodeEvent(ACode: TKeyCodeKind; AMods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := ACode;
  Result.Key.Modifiers := AMods;
end;

function KeyFunctionEvent(AF: Byte; AMods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := kcF;
  Result.Key.F := AF;
  Result.Key.Modifiers := AMods;
end;

function MouseEvent(AKind: TMouseEventKind; ABtn: TMouseButton;
  AX, AY: Word; AMods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evMouse;
  Result.Mouse.Kind := AKind;
  Result.Mouse.Button := ABtn;
  Result.Mouse.X := AX;
  Result.Mouse.Y := AY;
  Result.Mouse.Modifiers := AMods;
end;

function ResizeEvent(AWidth, AHeight: Word): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evResize;
  Result.Resize.Width := AWidth;
  Result.Resize.Height := AHeight;
end;

function IsNone(const AEv: TEvent): Boolean;
begin Result := AEv.Kind = evNone; end;

function IsKey(const AEv: TEvent): Boolean;
begin Result := AEv.Kind = evKey; end;

function IsMouse(const AEv: TEvent): Boolean;
begin Result := AEv.Kind = evMouse; end;

function IsResize(const AEv: TEvent): Boolean;
begin Result := AEv.Kind = evResize; end;

function IsKeyChar(const AEv: TEvent; ACh: LongWord): Boolean;
begin
  Result := (AEv.Kind = evKey) and (AEv.Key.Code = kcChar) and (AEv.Key.Ch = ACh);
end;

function IsKeyCode(const AEv: TEvent; ACode: TKeyCodeKind): Boolean;
begin
  Result := (AEv.Kind = evKey) and (AEv.Key.Code = ACode);
end;

function IsQuit(const AEv: TEvent): Boolean;
begin
  Result := IsKeyCode(AEv, kcEsc) or IsKeyChar(AEv, Ord('q'));
end;

end.
