unit nextpas.core.async.signal;
{**
 * @desc 异步信号处理：将 POSIX 信号转换为事件循环回调。
 *       使用 signalfd + 事件循环集成，避免传统信号处理的异步安全问题。
 *}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.async.base;

type
  {** 信号回调类型 *}
  TSignalCallback = procedure(ASigNum: Int32; AContext: Pointer);

  {** 信号处理器选项 *}
  TSignalOption = (
    soAutoUnblock,    { 注册后自动从 sigprocmask 中解除阻塞 }
    soOneShot         { 触发一次后自动注销 }
  );
  TSignalOptions = set of TSignalOption;

  {** 信号错误回调：当 ProcessSignals 中的回调抛出异常时调用 *}
  TSignalErrorCallback = procedure(ASigNum: Int32; const AError: string;
    AContext: Pointer);

  {** 异步信号处理器 *}
  IAsyncSignalHandler = interface
    ['{B7A3D4E5-6F8C-4A2B-9D1E-3C5F7A9B2D4E}']
    {** 注册信号处理回调 *}
    function RegisterSignal(ASigNum: Int32; ACallback: TSignalCallback;
      AContext: Pointer = nil; AOptions: TSignalOptions = []): Boolean;
    {** 注销信号处理 *}
    procedure UnregisterSignal(ASigNum: Int32);
    {** 注销所有信号处理 *}
    procedure UnregisterAll;
    {** 检查信号是否已注册 *}
    function IsRegistered(ASigNum: Int32): Boolean;
    {** 获取已注册信号数量 *}
    function Count: Integer;
    {** 获取 signalfd 文件描述符（用于事件循环集成） *}
    function Fd: cint;
    {** 处理 signalfd 可读事件 *}
    function ProcessSignals: Integer;
    {** 设置错误回调（可选，默认 stderr 输出） *}
    procedure SetErrorHandler(ACallback: TSignalErrorCallback; AContext: Pointer = nil);
  end;

{** 创建异步信号处理器 *}
function CreateAsyncSignalHandler: IAsyncSignalHandler;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.exception;

const
  MAX_SIGNALS = 32;
  SFD_NONBLOCK = 2048;
  SFD_CLOEXEC = 524288;
  _NSIG = 65;
  _NSIG_BPW = 64;
  _NSIG_WORDS = (_NSIG + _NSIG_BPW - 1) div _NSIG_BPW;

type
  TSignalEntry = record
    SigNum: Int32;
    Callback: TSignalCallback;
    Context: Pointer;
    Options: TSignalOptions;
    Active: Boolean;
  end;

  TSignalfdSiginfo = record
    ssi_signo: UInt32;
    ssi_errno: Int32;
    ssi_code: Int32;
    ssi_pid: UInt32;
    ssi_uid: UInt32;
    ssi_fd: Int32;
    ssi_tid: UInt32;
    ssi_band: UInt32;
    ssi_overrun: UInt32;
    ssi_sigval: UInt32;
    ssi_int: Int32;
    ssi_ptr: UInt64;
    ssi_utime: UInt64;
    ssi_stime: UInt64;
    ssi_addr: UInt64;
  end;

  TAsyncSignalHandler = class(TInterfacedObject, IAsyncSignalHandler)
  private
    FEntries: array[0..MAX_SIGNALS-1] of TSignalEntry;
    FCount: Integer;
    FFd: cint;
    FMask: sigset_t;
    FOnError: TSignalErrorCallback;
    FOnErrorCtx: Pointer;
    function FindEntry(ASigNum: Int32): Integer;
    procedure UpdateSignalfd;
  public
    constructor Create;
    destructor Destroy; override;
    function RegisterSignal(ASigNum: Int32; ACallback: TSignalCallback;
      AContext: Pointer = nil; AOptions: TSignalOptions = []): Boolean;
    procedure UnregisterSignal(ASigNum: Int32);
    procedure UnregisterAll;
    function IsRegistered(ASigNum: Int32): Boolean;
    function Count: Integer;
    function Fd: cint;
    function ProcessSignals: Integer;
    procedure SetErrorHandler(ACallback: TSignalErrorCallback; AContext: Pointer = nil);
  end;

{ Signal set manipulation - these are typically macros in C }
procedure sigemptyset(var ASet: sigset_t); inline;
begin
  FillChar(ASet, SizeOf(ASet), 0);
end;

procedure sigaddset(var ASet: sigset_t; ASigNum: Int32); inline;
var
  LWord: Integer;
  LBit: Integer;
begin
  if (ASigNum <= 0) or (ASigNum >= _NSIG) then
    Exit;
  LWord := (ASigNum - 1) div _NSIG_BPW;
  LBit := (ASigNum - 1) mod _NSIG_BPW;
  ASet[LWord] := ASet[LWord] or (1 shl LBit);
end;

procedure sigdelset(var ASet: sigset_t; ASigNum: Int32); inline;
var
  LWord: Integer;
  LBit: Integer;
begin
  if (ASigNum <= 0) or (ASigNum >= _NSIG) then
    Exit;
  LWord := (ASigNum - 1) div _NSIG_BPW;
  LBit := (ASigNum - 1) mod _NSIG_BPW;
  ASet[LWord] := ASet[LWord] and not (1 shl LBit);
end;

function CreateAsyncSignalHandler: IAsyncSignalHandler;
begin
  Result := TAsyncSignalHandler.Create;
end;

constructor TAsyncSignalHandler.Create;
begin
  inherited Create;
  FillChar(FEntries, SizeOf(FEntries), 0);
  FCount := 0;
  FFd := -1;
  sigemptyset(FMask);
  FOnError := nil;
  FOnErrorCtx := nil;
end;

destructor TAsyncSignalHandler.Destroy;
begin
  UnregisterAll;
  if FFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FFd);
    FFd := -1;
  end;
  inherited Destroy;
end;

function TAsyncSignalHandler.FindEntry(ASigNum: Int32): Integer;
var
  I: Integer;
begin
  for I := 0 to MAX_SIGNALS - 1 do
    if FEntries[I].Active and (FEntries[I].SigNum = ASigNum) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

procedure TAsyncSignalHandler.UpdateSignalfd;
begin
  if FFd >= 0 then
    nextpas.core.platform.posix.ffi.close(FFd);

  if FCount > 0 then
    FFd := signalfd(-1, @FMask, SFD_NONBLOCK or SFD_CLOEXEC)
  else
    FFd := -1;
end;

function TAsyncSignalHandler.RegisterSignal(ASigNum: Int32; ACallback: TSignalCallback;
  AContext: Pointer; AOptions: TSignalOptions): Boolean;
var
  LIdx: Integer;
begin
  Result := False;

  { Check if already registered }
  if FindEntry(ASigNum) >= 0 then
    Exit;

  { Find free slot }
  for LIdx := 0 to MAX_SIGNALS - 1 do
    if not FEntries[LIdx].Active then
      Break;
  if LIdx >= MAX_SIGNALS then
    Exit;

  { Block the signal }
  sigaddset(FMask, ASigNum);
  sigprocmask(SIG_BLOCK, @FMask, nil);

  { Store entry }
  FEntries[LIdx].SigNum := ASigNum;
  FEntries[LIdx].Callback := ACallback;
  FEntries[LIdx].Context := AContext;
  FEntries[LIdx].Options := AOptions;
  FEntries[LIdx].Active := True;
  Inc(FCount);

  { Update signalfd }
  UpdateSignalfd;

  Result := True;
end;

procedure TAsyncSignalHandler.UnregisterSignal(ASigNum: Int32);
var
  LIdx: Integer;
begin
  LIdx := FindEntry(ASigNum);
  if LIdx < 0 then
    Exit;

  { Clear entry }
  FEntries[LIdx].Active := False;
  FEntries[LIdx].Callback := nil;
  FEntries[LIdx].Context := nil;
  Dec(FCount);

  { Update signal mask }
  sigdelset(FMask, ASigNum);
  if FCount > 0 then
    sigprocmask(SIG_BLOCK, @FMask, nil)
  else
    sigprocmask(SIG_UNBLOCK, @FMask, nil);

  { Update signalfd }
  UpdateSignalfd;
end;

procedure TAsyncSignalHandler.UnregisterAll;
var
  I: Integer;
  LMask: sigset_t;
begin
  for I := 0 to MAX_SIGNALS - 1 do
    if FEntries[I].Active then
    begin
      FEntries[I].Active := False;
      FEntries[I].Callback := nil;
      FEntries[I].Context := nil;
    end;
  FCount := 0;

  { Unblock all signals }
  sigemptyset(LMask);
  sigprocmask(SIG_SETMASK, @LMask, nil);

  { Update signalfd }
  UpdateSignalfd;
end;

function TAsyncSignalHandler.IsRegistered(ASigNum: Int32): Boolean;
begin
  Result := FindEntry(ASigNum) >= 0;
end;

function TAsyncSignalHandler.Count: Integer;
begin
  Result := FCount;
end;

function TAsyncSignalHandler.Fd: cint;
begin
  Result := FFd;
end;

function TAsyncSignalHandler.ProcessSignals: Integer;
var
  LBuf: array[0..7] of TSignalfdSiginfo;
  LRead: ssize_t;
  LI: Integer;
  LIdx: Integer;
  LCount: Integer;
  LExcMsg: string;
begin
  Result := 0;
  if FFd < 0 then
    Exit;

  repeat
    LRead := nextpas.core.platform.posix.ffi.read(FFd, @LBuf[0], SizeOf(LBuf));
    if LRead <= 0 then
      Break;

    LCount := LRead div SizeOf(TSignalfdSiginfo);
    for LI := 0 to LCount - 1 do
    begin
      LIdx := FindEntry(Int32(LBuf[LI].ssi_signo));
      if LIdx >= 0 then
      begin
        try
          FEntries[LIdx].Callback(FEntries[LIdx].SigNum, FEntries[LIdx].Context);
        except
          on E: Exception do
          begin
            if Assigned(FOnError) then
              FOnError(FEntries[LIdx].SigNum, E.Message, FOnErrorCtx)
            else
            begin
              LExcMsg := 'signal callback error (sig=' +
                IntToStr(FEntries[LIdx].SigNum) + '): ' + E.Message;
              {$I-}
              WriteLn(StdErr, LExcMsg);
              {$I+}
            end;
          end;
        end;
        Inc(Result);

        { Auto-unregister for one-shot }
        if soOneShot in FEntries[LIdx].Options then
          UnregisterSignal(FEntries[LIdx].SigNum);
      end;
    end;
  until LRead < SizeOf(TSignalfdSiginfo);
end;

procedure TAsyncSignalHandler.SetErrorHandler(ACallback: TSignalErrorCallback;
  AContext: Pointer);
begin
  FOnError := ACallback;
  FOnErrorCtx := AContext;
end;

end.
