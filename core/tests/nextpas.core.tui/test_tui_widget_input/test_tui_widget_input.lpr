program test_tui_widget_input;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.input,
  nextpas.core.testing;

var T: TTestRunner;

{ === TInputState === }

procedure TestInputStateEmpty;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  Check(LS.Text = '', 'empty state has empty text');
  Check(LS.Cursor = 0, 'empty state cursor at 0');
  Check(LS.ScrollX = 0, 'empty state scroll at 0');
end;

procedure TestInputStateWithText;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello');
  Check(LS.Text = 'hello', 'state has text hello');
  Check(LS.Cursor = 5, 'cursor at end');
end;

procedure TestInputStateInsertChar;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  LS.InsertChar(Ord('a'));
  Check(LS.Text = 'a', 'insert a');
  Check(LS.Cursor = 1, 'cursor at 1');
  LS.InsertChar(Ord('b'));
  Check(LS.Text = 'ab', 'insert b');
  Check(LS.Cursor = 2, 'cursor at 2');
end;

procedure TestInputStateInsertStr;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  LS.InsertStr('hello');
  Check(LS.Text = 'hello', 'insert hello');
  Check(LS.Cursor = 5, 'cursor at 5');
end;

procedure TestInputStateDeleteBack;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.DeleteBack;
  Check(LS.Text = 'ab', 'delete back from abc');
  Check(LS.Cursor = 2, 'cursor at 2');
  LS.DeleteBack;
  Check(LS.Text = 'a', 'delete back from ab');
  Check(LS.Cursor = 1, 'cursor at 1');
  LS.DeleteBack;
  Check(LS.Text = '', 'delete back from a');
  Check(LS.Cursor = 0, 'cursor at 0');
  LS.DeleteBack;
  Check(LS.Text = '', 'delete back from empty is noop');
end;

procedure TestInputStateDeleteForward;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LS.DeleteForward;
  Check(LS.Text = 'ac', 'delete forward from middle');
  Check(LS.Cursor = 1, 'cursor stays');
  LS.DeleteForward;
  Check(LS.Text = 'a', 'delete forward from end-1');
  LS.DeleteForward;
  Check(LS.Text = 'a', 'delete forward at end is noop');
end;

procedure TestInputStateMoveLeft;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.MoveLeft;
  Check(LS.Cursor = 2, 'move left from 3');
  LS.MoveLeft;
  Check(LS.Cursor = 1, 'move left from 2');
  LS.MoveLeft;
  Check(LS.Cursor = 0, 'move left from 1');
  LS.MoveLeft;
  Check(LS.Cursor = 0, 'move left from 0 stays');
end;

procedure TestInputStateMoveRight;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 0;
  LS.MoveRight;
  Check(LS.Cursor = 1, 'move right from 0');
  LS.MoveRight;
  Check(LS.Cursor = 2, 'move right from 1');
  LS.MoveRight;
  Check(LS.Cursor = 3, 'move right from 2');
  LS.MoveRight;
  Check(LS.Cursor = 3, 'move right from 3 stays');
end;

procedure TestInputStateMoveHome;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.MoveHome;
  Check(LS.Cursor = 0, 'move home');
end;

procedure TestInputStateMoveEnd;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LS.MoveEnd;
  Check(LS.Cursor = 3, 'move end');
end;

procedure TestInputStateCursorCol;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  Check(LS.CursorCol = 3, 'cursor col at end');
  LS.Cursor := 1;
  Check(LS.CursorCol = 1, 'cursor col at 1');
end;

procedure TestInputStateTextWidth;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  Check(LS.TextWidth = 3, 'text width of abc');
  LS := TInputState.Empty;
  Check(LS.TextWidth = 0, 'text width of empty');
end;

{ === IInput Builders === }

procedure TestInputNew;
var LI: IInput;
begin
  LI := TInput.New;
  Check(LI <> nil, 'TInput.New returns non-nil');
end;

procedure TestInputWithPlaceholder;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithPlaceholder('type here');
  LS := TInputState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('type here', LRow) > 0, 'placeholder visible when empty');
  finally LBuf.Free; end;
end;

procedure TestInputPlaceholderHidden;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithPlaceholder('type here');
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('hello', LRow) > 0, 'text visible');
    Check(Pos('type here', LRow) = 0, 'placeholder hidden when text exists');
  finally LBuf.Free; end;
end;

procedure TestInputWithMask;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithMask('*');
  LS := TInputState.WithText('secret');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('secret', LRow) = 0, 'original text hidden');
    Check(Pos('*', LRow) > 0, 'mask char visible');
  finally LBuf.Free; end;
end;

procedure TestInputWithStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithStyle(TStyle.Default.WithFg(IndexedColor(1)));
  LS := TInputState.WithText('styled');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'styled input renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithPlaceholderStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New
    .WithPlaceholder('hint')
    .WithPlaceholderStyle(TStyle.Default.WithFg(IndexedColor(8)));
  LS := TInputState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'input with placeholder style renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithCursorStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithCursorStyle(TStyle.Default.WithBg(IndexedColor(4)));
  LS := TInputState.WithText('abc');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'input with cursor style renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithBlock;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithBlock(TBlock.New.WithTitle('Name'));
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 3), LBuf, LS);
    Check(True, 'input with block renders');
  finally LBuf.Free; end;
end;

procedure TestInputRenderInline;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New;
  LS := TInputState.WithText('inline');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderInline(LBuf, 0, 0, 20, LS);
    Check(True, 'inline render works');
  finally LBuf.Free; end;
end;

procedure TestInputAsIWidget;
var LI: IInput; LW: IWidget;
begin
  LI := TInput.New;
  LW := LI as IWidget;
  Check(LW <> nil, 'IInput casts to IWidget');
end;

{ === TInputState.HandleKey === }

procedure TestInputStateHandleKeyChar;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.Empty;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcChar;
  KE.Ch := Ord('x');
  Check(LS.HandleKey(KE), 'handle key returns true');
  Check(LS.Text = 'x', 'char inserted');
end;

procedure TestInputStateHandleKeyBackspace;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('ab');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  Check(LS.HandleKey(KE), 'handle backspace');
  Check(LS.Text = 'a', 'char deleted');
end;

procedure TestInputStateHandleKeyLeft;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcLeft;
  LS.HandleKey(KE);
  Check(LS.Cursor = 2, 'cursor moved left');
end;

procedure TestInputStateHandleKeyRight;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcRight;
  LS.HandleKey(KE);
  Check(LS.Cursor = 2, 'cursor moved right');
end;

procedure TestInputStateHandleKeyHome;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcHome;
  LS.HandleKey(KE);
  Check(LS.Cursor = 0, 'cursor at home');
end;

procedure TestInputStateHandleKeyEnd;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcEnd;
  LS.HandleKey(KE);
  Check(LS.Cursor = 3, 'cursor at end');
end;

procedure TestInputStateHandleKeyDelete;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcDelete;
  LS.HandleKey(KE);
  Check(LS.Text = 'ac', 'forward delete');
end;

begin
  T := TTestRunner.Create('test_tui_widget_input');
  try
    { TInputState }
    T.Run('InputState Empty', @TestInputStateEmpty);
    T.Run('InputState WithText', @TestInputStateWithText);
    T.Run('InputState InsertChar', @TestInputStateInsertChar);
    T.Run('InputState InsertStr', @TestInputStateInsertStr);
    T.Run('InputState DeleteBack', @TestInputStateDeleteBack);
    T.Run('InputState DeleteForward', @TestInputStateDeleteForward);
    T.Run('InputState MoveLeft', @TestInputStateMoveLeft);
    T.Run('InputState MoveRight', @TestInputStateMoveRight);
    T.Run('InputState MoveHome', @TestInputStateMoveHome);
    T.Run('InputState MoveEnd', @TestInputStateMoveEnd);
    T.Run('InputState CursorCol', @TestInputStateCursorCol);
    T.Run('InputState TextWidth', @TestInputStateTextWidth);

    { IInput Builders }
    T.Run('Input New', @TestInputNew);
    T.Run('Input WithPlaceholder', @TestInputWithPlaceholder);
    T.Run('Input placeholder hidden', @TestInputPlaceholderHidden);
    T.Run('Input WithMask', @TestInputWithMask);
    T.Run('Input WithStyle', @TestInputWithStyle);
    T.Run('Input WithPlaceholderStyle', @TestInputWithPlaceholderStyle);
    T.Run('Input WithCursorStyle', @TestInputWithCursorStyle);
    T.Run('Input WithBlock', @TestInputWithBlock);
    T.Run('Input RenderInline', @TestInputRenderInline);
    T.Run('Input as IWidget', @TestInputAsIWidget);

    { HandleKey }
    T.Run('HandleKey char', @TestInputStateHandleKeyChar);
    T.Run('HandleKey backspace', @TestInputStateHandleKeyBackspace);
    T.Run('HandleKey left', @TestInputStateHandleKeyLeft);
    T.Run('HandleKey right', @TestInputStateHandleKeyRight);
    T.Run('HandleKey home', @TestInputStateHandleKeyHome);
    T.Run('HandleKey end', @TestInputStateHandleKeyEnd);
    T.Run('HandleKey delete', @TestInputStateHandleKeyDelete);

    WriteLn;
    T.Summary;
  finally
  end;
end.
