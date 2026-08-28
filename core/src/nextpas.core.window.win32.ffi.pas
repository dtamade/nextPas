unit nextpas.core.window.win32.ffi;

{** @desc Win32 窗口子集 ABI 声明层（window 家族）。
       只含窗口壳必需的 Win32 类型与函数指针变量——无逻辑、无 external；
       绑定真相归 window.win32.loader（经 nextpas.core.platform.dl）。

       覆盖：RegisterClassEx/CreateWindowEx/ShowWindow/DestroyWindow/
       SetWindowText/GetWindowText/GetClientRect/GetWindowRect/
       IsIconic/IsZoomed/GetDpiForWindow/PostMessage/PostQuitMessage/
       DispatchMessage/GetMessage/PeekMessage/DefWindowProc 族。

       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  HWND = Pointer;
  HINSTANCE = Pointer;
  HMENU = Pointer;
  HICON = Pointer;
  HCURSOR = Pointer;
  HBRUSH = Pointer;
  ATOM = Word;
  UINT = Cardinal;
  WPARAM = PtrUInt;
  LPARAM = PtrInt;
  LRESULT = PtrInt;
  DWORD = Cardinal;
  BOOL = LongBool;
  LONG = Int32;
  WORD = UInt16;
  BYTE = UInt8;

const
  WS_OVERLAPPED       = $00000000;
  WS_CAPTION          = $00C00000;
  WS_SYSMENU          = $00080000;
  WS_THICKFRAME       = $00040000;
  WS_MINIMIZEBOX      = $00020000;
  WS_MAXIMIZEBOX      = $00010000;
  WS_OVERLAPPEDWINDOW = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX;
  WS_VISIBLE          = $10000000;
  WS_POPUP            = $80000000;

  WS_EX_APPWINDOW     = $00040000;
  WS_EX_WINDOWEDGE    = $00000100;

  SW_HIDE             = 0;
  SW_SHOWNORMAL       = 1;
  SW_SHOW             = 5;
  SW_MINIMIZE         = 6;
  SW_RESTORE          = 9;
  SW_MAXIMIZE         = 3;

  CW_USEDEFAULT       = Int32($80000000);

  WM_DESTROY          = $0002;
  WM_CLOSE            = $0010;
  WM_SIZE             = $0005;
  WM_MOVE             = $0003;
  WM_GETMINMAXINFO    = $0024;
  WM_SETFOCUS         = $0007;
  WM_KILLFOCUS        = $0008;
  WM_DPICHANGED       = $02E0;
  WM_KEYDOWN          = $0100;
  WM_KEYUP            = $0101;
  WM_LBUTTONDOWN      = $0201;
  WM_LBUTTONUP        = $0202;
  WM_RBUTTONDOWN      = $0204;
  WM_RBUTTONUP        = $0205;
  WM_MBUTTONDOWN      = $0207;
  WM_MBUTTONUP        = $0208;
  WM_MOUSEMOVE        = $0200;
  WM_QUIT             = $0012;
  WM_APP              = $8000;

  SIZE_RESTORED       = 0;
  SIZE_MINIMIZED      = 1;
  SIZE_MAXIMIZED      = 2;

  PM_REMOVE           = $0001;

  CS_HREDRAW          = $0002;
  CS_VREDRAW          = $0001;
  CS_OWNDC            = $0020;

  IDC_ARROW           = PAnsiChar(32512);
  COLOR_WINDOW        = 5;

type
  POINT = record x, y: LONG; end;
  RECT = record left, top, right, bottom: LONG; end;
  PRect = ^RECT;
  TMsg = record
    hwnd: HWND;
    message: UINT;
    wParam: WPARAM;
    lParam: LPARAM;
    time: DWORD;
    pt: POINT;
  end;
  PMSG = ^TMsg;

  WNDCLASSEX = record
    cbSize: UINT;
    style: UINT;
    lpfnWndProc: Pointer;
    cbClsExtra: Integer;
    cbWndExtra: Integer;
    hInstance: HINSTANCE;
    hIcon: HICON;
    hCursor: HCURSOR;
    hbrBackground: HBRUSH;
    lpszMenuName: PAnsiChar;
    lpszClassName: PAnsiChar;
    hIconSm: HICON;
  end;
  PWNDCLASSEX = ^WNDCLASSEX;

  MINMAXINFO = record
    ptReserved: POINT;
    ptMaxSize: POINT;
    ptMaxPosition: POINT;
    ptMinTrackSize: POINT;
    ptMaxTrackSize: POINT;
  end;
  PMINMAXINFO = ^MINMAXINFO;

  TWndProc = function(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

function HIWORD(AValue: DWORD): WORD; inline;
function LOWORD(AValue: DWORD): WORD; inline;

var
  RegisterClassExA: function(lpwcx: PWNDCLASSEX): ATOM; stdcall;
  CreateWindowExA: function(dwExStyle: DWORD; lpClassName: PAnsiChar; lpWindowName: PAnsiChar;
    dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: HWND; hMenu: HMENU;
    hInstance: HINSTANCE; lpParam: Pointer): HWND; stdcall;
  DefWindowProcA: function(hwnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
  DestroyWindow: function(hwnd: HWND): BOOL; stdcall;
  ShowWindow: function(hwnd: HWND; nCmdShow: Integer): BOOL; stdcall;
  IsWindowVisible: function(hwnd: HWND): BOOL; stdcall;
  IsIconic: function(hwnd: HWND): BOOL; stdcall;
  IsZoomed: function(hwnd: HWND): BOOL; stdcall;
  SetWindowTextA: function(hwnd: HWND; lpString: PAnsiChar): BOOL; stdcall;
  GetWindowTextA: function(hwnd: HWND; lpString: PAnsiChar; nMaxCount: Integer): Integer; stdcall;
  GetClientRect: function(hwnd: HWND; lpRect: PRect): BOOL; stdcall;
  GetWindowRect: function(hwnd: HWND; lpRect: PRect): BOOL; stdcall;
  MoveWindow: function(hwnd: HWND; X, Y, nWidth, nHeight: Integer; bRepaint: BOOL): BOOL; stdcall;
  SetWindowPos: function(hwnd: HWND; hWndInsertAfter: HWND; X, Y, cx, cy: Integer; uFlags: UINT): BOOL; stdcall;
  GetDpiForWindow: function(hwnd: HWND): UINT; stdcall;
  GetModuleHandleA: function(lpModuleName: PAnsiChar): HINSTANCE; stdcall;
  LoadCursorA: function(hInstance: HINSTANCE; lpCursorName: PAnsiChar): HCURSOR; stdcall;
  PostMessageA: function(hwnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL; stdcall;
  PostQuitMessage: procedure(nExitCode: Integer); stdcall;
  GetMessageA: function(lpMsg: PMSG; hWnd: HWND; wMsgFilterMin, wMsgFilterMax: UINT): BOOL; stdcall;
  PeekMessageA: function(lpMsg: PMSG; hWnd: HWND; wMsgFilterMin, wMsgFilterMax: UINT; wRemoveMsg: UINT): BOOL; stdcall;
  WaitMessage: function: BOOL; stdcall;
  TranslateMessage: function(lpMsg: PMSG): BOOL; stdcall;
  DispatchMessageA: function(lpMsg: PMSG): LRESULT; stdcall;
  SetWindowLongPtrA: function(hwnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt; stdcall;
  GetWindowLongPtrA: function(hwnd: HWND; nIndex: Integer): PtrInt; stdcall;
  GetKeyState: function(nVirtKey: Integer): SmallInt; stdcall;

const
  GWLP_USERDATA = -21;

  VK_SHIFT   = $10;
  VK_CONTROL = $11;
  VK_MENU    = $12;
  VK_LWIN    = $5B;
  VK_RWIN    = $5C;

implementation

function HIWORD(AValue: DWORD): WORD; inline;
begin
  Result := WORD((AValue shr 16) and $FFFF);
end;

function LOWORD(AValue: DWORD): WORD; inline;
begin
  Result := WORD(AValue and $FFFF);
end;

end.
