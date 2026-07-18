unit nextpas.core.io.async.fileio;
{**
 * @desc 异步文件 I/O：集成事件循环的非阻塞文件操作。
 *       使用线程池执行阻塞的文件 I/O，结果通过事件循环回调通知。
 *       注意：使用此模块的程序需要在 uses 中包含 cthreads。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 文件 I/O 结果 }
  TFileIOResult = record
    BytesTransferred: UInt32;
    Error: Int32;
    function Success: Boolean; inline;
  end;

  { 文件 I/O 回调 }
  TFileIOCallback = procedure(const AResult: TFileIOResult; AContext: Pointer);
  TFileIOCallbackRef = reference to procedure(const AResult: TFileIOResult; AContext: Pointer);

{ 异步文件读取 }
function AsyncFileRead(const ALoop: TAsyncLoop; const APath: string;
  ABuf: Pointer; ASize: UInt32; ACallback: TFileIOCallback;
  AContext: Pointer = nil): Boolean;

function AsyncFileReadRef(const ALoop: TAsyncLoop; const APath: string;
  ABuf: Pointer; ASize: UInt32; ACallback: TFileIOCallbackRef;
  AContext: Pointer = nil): Boolean;

{ 异步文件写入 }
function AsyncFileWrite(const ALoop: TAsyncLoop; const APath: string;
  const AData; ASize: UInt32; ACallback: TFileIOCallback;
  AContext: Pointer = nil): Boolean;

function AsyncFileWriteRef(const ALoop: TAsyncLoop; const APath: string;
  const AData; ASize: UInt32; ACallback: TFileIOCallbackRef;
  AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.utf8,
  nextpas.core.platform.thread;

type

  PFileIOContext = ^TFileIOContext;
  TFileIOContext = record
    Path: AnsiString;  { UTF-8 编码路径，线程安全 }
    Loop: TAsyncLoop;
    Buf: Pointer;
    Size: UInt32;
    Data: Pointer;
    IsWrite: Boolean;
    Callback: TFileIOCallback;
    CallbackRef: TFileIOCallbackRef;
    Context: Pointer;
  end;

  PFileIOPostContext = ^TFileIOPostContext;
  TFileIOPostContext = record
    Loop: TAsyncLoop;
    Callback: TFileIOCallback;
    CallbackRef: TFileIOCallbackRef;
    Context: Pointer;
    Result: TFileIOResult;
  end;

function TFileIOResult.Success: Boolean;
begin
  Result := Error = 0;
end;

{ 完成回调 - 在事件循环线程中执行 }
procedure FileIOPostCallback(AContext: Pointer);
var
  LPostCtx: PFileIOPostContext;
begin
  LPostCtx := PFileIOPostContext(AContext);
  try
    if Assigned(LPostCtx^.Callback) then
      LPostCtx^.Callback(LPostCtx^.Result, LPostCtx^.Context)
    else if Assigned(LPostCtx^.CallbackRef) then
      LPostCtx^.CallbackRef(LPostCtx^.Result, LPostCtx^.Context);
  finally
    Dispose(LPostCtx);
  end;
end;

{ 文件 I/O 线程 }
function FileIOThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PFileIOContext;
  LResult: TFileIOResult;
  LPostCtx: PFileIOPostContext;
  LFile: file;
  LBytesRead, LBytesWritten: UInt32;
  LIOResult: Int32;
begin
  Result := nil;
  LCtx := PFileIOContext(AParam);
  try
    FillChar(LResult, SizeOf(LResult), 0);

    if LCtx^.IsWrite then
    begin
      { 写入文件 }
      Assign(LFile, LCtx^.Path);
      {$I-}
      Rewrite(LFile, 1);
      {$I+}
      LIOResult := IOResult;
      if LIOResult <> 0 then
      begin
        LResult.Error := LIOResult;
      end
      else
      begin
        BlockWrite(LFile, LCtx^.Data^, LCtx^.Size, LBytesWritten);
        LResult.Error := IOResult;
        if LResult.Error = 0 then
          LResult.BytesTransferred := LBytesWritten;
        Close(LFile);
      end;
    end
    else
    begin
      { 读取文件 }
      Assign(LFile, LCtx^.Path);
      {$I-}
      Reset(LFile, 1);
      {$I+}
      LIOResult := IOResult;
      if LIOResult <> 0 then
      begin
        LResult.Error := LIOResult;
      end
      else
      begin
        BlockRead(LFile, LCtx^.Buf^, LCtx^.Size, LBytesRead);
        LResult.Error := IOResult;
        if LResult.Error = 0 then
          LResult.BytesTransferred := LBytesRead;
        Close(LFile);
      end;
    end;

    { 通过事件循环回调通知结果 }
    New(LPostCtx);
    LPostCtx^.Loop := LCtx^.Loop;
    LPostCtx^.Callback := LCtx^.Callback;
    LPostCtx^.CallbackRef := LCtx^.CallbackRef;
    LPostCtx^.Context := LCtx^.Context;
    LPostCtx^.Result := LResult;
    LCtx^.Loop.Post(@FileIOPostCallback, LPostCtx);

  finally
    Dispose(LCtx);
  end;
end;

function AsyncFileRead(const ALoop: TAsyncLoop; const APath: string;
  ABuf: Pointer; ASize: UInt32; ACallback: TFileIOCallback;
  AContext: Pointer): Boolean;
var
  LCtx: PFileIOContext;
  LHandle: TPlatformThreadHandle;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async file: loop not valid');

  New(LCtx);
  LCtx^.Path := UTF8Encode(APath);
  LCtx^.Loop := ALoop;
  LCtx^.Buf := ABuf;
  LCtx^.Size := ASize;
  LCtx^.Data := nil;
  LCtx^.IsWrite := False;
  LCtx^.Callback := ACallback;
  LCtx^.CallbackRef := nil;
  LCtx^.Context := AContext;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @FileIOThread, LCtx) <> 0 then
  begin
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

function AsyncFileReadRef(const ALoop: TAsyncLoop; const APath: string;
  ABuf: Pointer; ASize: UInt32; ACallback: TFileIOCallbackRef;
  AContext: Pointer): Boolean;
var
  LCtx: PFileIOContext;
  LHandle: TPlatformThreadHandle;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async file: loop not valid');

  New(LCtx);
  LCtx^.Path := UTF8Encode(APath);
  LCtx^.Loop := ALoop;
  LCtx^.Buf := ABuf;
  LCtx^.Size := ASize;
  LCtx^.Data := nil;
  LCtx^.IsWrite := False;
  LCtx^.Callback := nil;
  LCtx^.CallbackRef := ACallback;
  LCtx^.Context := AContext;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @FileIOThread, LCtx) <> 0 then
  begin
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

function AsyncFileWrite(const ALoop: TAsyncLoop; const APath: string;
  const AData; ASize: UInt32; ACallback: TFileIOCallback;
  AContext: Pointer): Boolean;
var
  LCtx: PFileIOContext;
  LHandle: TPlatformThreadHandle;
  LDataCopy: Pointer;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async file: loop not valid');

  { 复制数据到堆上，避免异步生命周期问题 }
  GetMem(LDataCopy, ASize);
  Move(AData, LDataCopy^, ASize);

  New(LCtx);
  LCtx^.Path := UTF8Encode(APath);
  LCtx^.Loop := ALoop;
  LCtx^.Buf := nil;
  LCtx^.Size := ASize;
  LCtx^.Data := LDataCopy;
  LCtx^.IsWrite := True;
  LCtx^.Callback := ACallback;
  LCtx^.CallbackRef := nil;
  LCtx^.Context := AContext;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @FileIOThread, LCtx) <> 0 then
  begin
    FreeMem(LDataCopy);
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

function AsyncFileWriteRef(const ALoop: TAsyncLoop; const APath: string;
  const AData; ASize: UInt32; ACallback: TFileIOCallbackRef;
  AContext: Pointer): Boolean;
var
  LCtx: PFileIOContext;
  LHandle: TPlatformThreadHandle;
  LDataCopy: Pointer;
begin
  if not ALoop.IsValid then
    raise EInvalidOperationError.Create('async file: loop not valid');

  { 复制数据到堆上 }
  GetMem(LDataCopy, ASize);
  Move(AData, LDataCopy^, ASize);

  New(LCtx);
  LCtx^.Path := UTF8Encode(APath);
  LCtx^.Loop := ALoop;
  LCtx^.Buf := nil;
  LCtx^.Size := ASize;
  LCtx^.Data := LDataCopy;
  LCtx^.IsWrite := True;
  LCtx^.Callback := nil;
  LCtx^.CallbackRef := ACallback;
  LCtx^.Context := AContext;

  FillChar(LHandle, SizeOf(LHandle), 0);
  if platform_thread_create(LHandle, @FileIOThread, LCtx) <> 0 then
  begin
    FreeMem(LDataCopy);
    Dispose(LCtx);
    Exit(False);
  end;
  platform_thread_detach(LHandle);
  Result := True;
end;

end.
