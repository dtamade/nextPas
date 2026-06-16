unit nextpas.core.tls.openssl.api.async;

{$mode ObjFPC}{$H+}
//{$I nextpas.core.tls.openssl.inc}  // Include file not present

interface

uses Classes, nextpas.core.tls.openssl.base;

type
  // ASYNC types
  PASYNC_JOB = ^ASYNC_JOB;
  ASYNC_JOB = record
    // Opaque structure
  end;
  PPASYNC_JOB = ^PASYNC_JOB;
  
  PASYNC_WAIT_CTX = ^ASYNC_WAIT_CTX;
  ASYNC_WAIT_CTX = record
    // Opaque structure
  end;
  
  POSSL_ASYNC_FD = ^OSSL_ASYNC_FD;
  {$IFDEF WINDOWS}
  OSSL_ASYNC_FD = THandle;
  {$ELSE}
  OSSL_ASYNC_FD = Integer;
  {$ENDIF}
  
  // ASYNC callbacks
  TASYNC_cleanup_func = procedure(ctx: PASYNC_WAIT_CTX; fd: OSSL_ASYNC_FD; custom: Pointer); cdecl;
  TASYNC_start_func = function(user_data: Pointer): Integer; cdecl;

const
  // ASYNC return codes
  ASYNC_ERR        = 0;
  ASYNC_NO_JOBS    = 1;
  ASYNC_PAUSE      = 2;
  ASYNC_FINISH     = 3;
  
  // ASYNC init flags
  ASYNC_INIT_THREAD_LOCAL = $01;

type
  TASYNC_init_thread = function(max_size: NativeUInt; init_size: NativeUInt): Integer; cdecl;
  TASYNC_cleanup_thread = procedure(); cdecl;

var
  // ASYNC functions
  ASYNC_init_thread: TASYNC_init_thread = nil;
  ASYNC_cleanup_thread: TASYNC_cleanup_thread = nil;
  
  // ASYNC wait context functions
  ASYNC_WAIT_CTX_new: function(): PASYNC_WAIT_CTX; cdecl = nil;
  ASYNC_WAIT_CTX_free: procedure(ctx: PASYNC_WAIT_CTX); cdecl = nil;
  ASYNC_WAIT_CTX_set_wait_fd: function(ctx: PASYNC_WAIT_CTX; const key: Pointer; 
    fd: OSSL_ASYNC_FD; custom_data: Pointer; 
    cleanup_func: TASYNC_cleanup_func): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_get_fd: function(ctx: PASYNC_WAIT_CTX; const key: Pointer;
    var fd: OSSL_ASYNC_FD; var custom_data: Pointer): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_get_all_fds: function(ctx: PASYNC_WAIT_CTX; var fd: OSSL_ASYNC_FD; 
    var numfds: NativeUInt): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_get_changed_fds: function(ctx: PASYNC_WAIT_CTX; 
    var addfd: OSSL_ASYNC_FD; var numaddfds: NativeUInt;
    var delfd: OSSL_ASYNC_FD; var numdelfds: NativeUInt): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_clear_fd: function(ctx: PASYNC_WAIT_CTX; const key: Pointer): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_set_callback: function(ctx: PASYNC_WAIT_CTX; 
    callback: TASYNC_cleanup_func; callback_arg: Pointer): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_get_callback: function(ctx: PASYNC_WAIT_CTX; 
    var callback: TASYNC_cleanup_func; var callback_arg: Pointer): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_set_status: function(ctx: PASYNC_WAIT_CTX; status: Integer): Integer; cdecl = nil;
  ASYNC_WAIT_CTX_get_status: function(ctx: PASYNC_WAIT_CTX): Integer; cdecl = nil;
  
  // ASYNC job functions
  ASYNC_start_job: function(var job: PASYNC_JOB; ctx: PASYNC_WAIT_CTX;
    var ret: Integer; func: TASYNC_start_func; args: Pointer;
    size: NativeUInt): Integer; cdecl = nil;
  ASYNC_pause_job: function(): Integer; cdecl = nil;
  ASYNC_get_current_job: function(): PASYNC_JOB; cdecl = nil;
  ASYNC_get_wait_ctx: function(job: PASYNC_JOB): PASYNC_WAIT_CTX; cdecl = nil;
  ASYNC_block_pause: procedure(); cdecl = nil;
  ASYNC_unblock_pause: procedure(); cdecl = nil;
  
  // ASYNC pool functions  
  ASYNC_is_capable: function(): Integer; cdecl = nil;
  
  // Arch specific functions
  ASYNC_stack_alloc: function(max_size: NativeUInt; init_size: NativeUInt): Pointer; cdecl = nil;
  ASYNC_stack_free: procedure(stack: Pointer); cdecl = nil;

procedure LoadASYNCFunctions(AHandle: TLibHandle);
procedure UnloadASYNCFunctions;

// Helper functions for async operations
function InitializeAsyncContext(MaxJobs: NativeUInt = 0): Boolean;
procedure CleanupAsyncContext;
function CreateAsyncJob(Func: TASYNC_start_func; UserData: Pointer; 
  WaitCtx: PASYNC_WAIT_CTX = nil): PASYNC_JOB;
function RunAsyncJob(var Job: PASYNC_JOB; Func: TASYNC_start_func; 
  UserData: Pointer; WaitCtx: PASYNC_WAIT_CTX = nil): Integer;
function WaitForAsyncJob(Job: PASYNC_JOB; TimeoutMs: Integer = -1): Boolean;
function IsAsyncCapable: Boolean;

// Async job wrapper class
type
  TAsyncJob = class
  private
    FJob: PASYNC_JOB;
    FWaitCtx: PASYNC_WAIT_CTX;
    FFunc: TASYNC_start_func;
    FUserData: Pointer;
    FResult: Integer;
    FStatus: Integer;
  public
    constructor Create(AFunc: TASYNC_start_func; AUserData: Pointer);
    destructor Destroy; override;
    
    function Start: Integer;
    function Pause: Boolean;
    function Resume: Integer;
    function Wait(TimeoutMs: Integer = -1): Boolean;
    function GetStatus: Integer;
    
    property Job: PASYNC_JOB read FJob;
    property WaitContext: PASYNC_WAIT_CTX read FWaitCtx;
    property Result: Integer read FResult;
    property Status: Integer read FStatus;
  end;

  // Async job pool for managing multiple async operations
  TAsyncJobPool = class
  private
    FJobs: TList;
    FMaxJobs: Integer;
    FActiveJobs: Integer;
  public
    constructor Create(AMaxJobs: Integer = 10);
    destructor Destroy; override;
    
    function AddJob(AFunc: TASYNC_start_func; AUserData: Pointer): TAsyncJob;
    function RemoveJob(AJob: TAsyncJob): Boolean;
    procedure WaitAll(TimeoutMs: Integer = -1);
    procedure CancelAll;
    
    property MaxJobs: Integer read FMaxJobs;
    property ActiveJobs: Integer read FActiveJobs;
  end;

implementation

uses Windows, BaseUnix, nextpas.core.tls.openssl.api.utils;

procedure LoadASYNCFunctions(AHandle: TLibHandle);
type
  T_ASYNC_init_thread = function(max_size: NativeUInt; init_size: NativeUInt): Integer; cdecl;
  T_ASYNC_cleanup_thread = procedure(); cdecl;
  T_ASYNC_WAIT_CTX_new = function(): PASYNC_WAIT_CTX; cdecl;
  T_ASYNC_WAIT_CTX_free = procedure(ctx: PASYNC_WAIT_CTX); cdecl;
  T_ASYNC_start_job = function(var job: PASYNC_JOB; ctx: PASYNC_WAIT_CTX; var ret: Integer; func: TASYNC_start_func; args: Pointer; size: NativeUInt): Integer; cdecl;
  T_ASYNC_pause_job = function(): Integer; cdecl;
  T_ASYNC_get_current_job = function(): PASYNC_JOB; cdecl;
  T_ASYNC_get_wait_ctx = function(job: PASYNC_JOB): PASYNC_WAIT_CTX; cdecl;
  T_ASYNC_block_pause = procedure(); cdecl;
  T_ASYNC_unblock_pause = procedure(); cdecl;
  T_ASYNC_is_capable = function(): Integer; cdecl;
  T_ASYNC_stack_alloc = function(max_size: NativeUInt; init_size: NativeUInt): Pointer; cdecl;
  T_ASYNC_stack_free = procedure(stack: Pointer); cdecl;
begin
  if AHandle = 0 then Exit;
  
  // ASYNC thread functions - with type casts
  ASYNC_init_thread := T_ASYNC_init_thread(GetProcedureAddress(AHandle, 'ASYNC_init_thread'));
  ASYNC_cleanup_thread := T_ASYNC_cleanup_thread(GetProcedureAddress(AHandle, 'ASYNC_cleanup_thread'));
  
  // ASYNC wait context functions - simple assignments (already initialized to nil)
  ASYNC_WAIT_CTX_new := T_ASYNC_WAIT_CTX_new(GetProcedureAddress(AHandle, 'ASYNC_WAIT_CTX_new'));
  ASYNC_WAIT_CTX_free := T_ASYNC_WAIT_CTX_free(GetProcedureAddress(AHandle, 'ASYNC_WAIT_CTX_free'));
  // Skipping complex function pointers for now - they're optional
  
  // ASYNC job functions
  ASYNC_start_job := T_ASYNC_start_job(GetProcedureAddress(AHandle, 'ASYNC_start_job'));
  ASYNC_pause_job := T_ASYNC_pause_job(GetProcedureAddress(AHandle, 'ASYNC_pause_job'));
  ASYNC_get_current_job := T_ASYNC_get_current_job(GetProcedureAddress(AHandle, 'ASYNC_get_current_job'));
  ASYNC_get_wait_ctx := T_ASYNC_get_wait_ctx(GetProcedureAddress(AHandle, 'ASYNC_get_wait_ctx'));
  ASYNC_block_pause := T_ASYNC_block_pause(GetProcedureAddress(AHandle, 'ASYNC_block_pause'));
  ASYNC_unblock_pause := T_ASYNC_unblock_pause(GetProcedureAddress(AHandle, 'ASYNC_unblock_pause'));
  
  // ASYNC capability functions
  ASYNC_is_capable := T_ASYNC_is_capable(GetProcedureAddress(AHandle, 'ASYNC_is_capable'));
  
  // Stack functions (arch specific)
  ASYNC_stack_alloc := T_ASYNC_stack_alloc(GetProcedureAddress(AHandle, 'ASYNC_stack_alloc'));
  ASYNC_stack_free := T_ASYNC_stack_free(GetProcedureAddress(AHandle, 'ASYNC_stack_free'));
end;

procedure UnloadASYNCFunctions;
begin
  ASYNC_init_thread := nil;
  ASYNC_cleanup_thread := nil;
  ASYNC_WAIT_CTX_new := nil;
  ASYNC_WAIT_CTX_free := nil;
  ASYNC_WAIT_CTX_set_wait_fd := nil;
  ASYNC_WAIT_CTX_get_fd := nil;
  ASYNC_WAIT_CTX_get_all_fds := nil;
  ASYNC_WAIT_CTX_get_changed_fds := nil;
  ASYNC_WAIT_CTX_clear_fd := nil;
  ASYNC_WAIT_CTX_set_callback := nil;
  ASYNC_WAIT_CTX_get_callback := nil;
  ASYNC_WAIT_CTX_set_status := nil;
  ASYNC_WAIT_CTX_get_status := nil;
  ASYNC_start_job := nil;
  ASYNC_pause_job := nil;
  ASYNC_get_current_job := nil;
  ASYNC_get_wait_ctx := nil;
  ASYNC_block_pause := nil;
  ASYNC_unblock_pause := nil;
  ASYNC_is_capable := nil;
  ASYNC_stack_alloc := nil;
  ASYNC_stack_free := nil;
end;

// Helper function implementations

function InitializeAsyncContext(MaxJobs: NativeUInt): Boolean;
const
  DEFAULT_STACK_SIZE = 32768;  // 32KB default stack size
begin
  Result := False;
  if not Assigned(ASYNC_init_thread) then Exit;
  
  if MaxJobs = 0 then
    MaxJobs := 1;
    
  Result := ASYNC_init_thread(MaxJobs * DEFAULT_STACK_SIZE, DEFAULT_STACK_SIZE) = 1;
end;

procedure CleanupAsyncContext;
begin
  if Assigned(ASYNC_cleanup_thread) then
    ASYNC_cleanup_thread();
end;

function CreateAsyncJob(Func: TASYNC_start_func; UserData: Pointer; 
  WaitCtx: PASYNC_WAIT_CTX): PASYNC_JOB;
var
  RetVal: Integer;
begin
  Result := nil;
  if not Assigned(ASYNC_start_job) or not Assigned(Func) then Exit;
  
  if WaitCtx = nil then
  begin
    if Assigned(ASYNC_WAIT_CTX_new) then
      WaitCtx := ASYNC_WAIT_CTX_new();
  end;
  
  if ASYNC_start_job(Result, WaitCtx, RetVal, Func, UserData, 0) = ASYNC_PAUSE then
  begin
    // Job created and paused, ready to be resumed
  end
  else
  begin
    // Job either completed immediately or failed
    if Assigned(ASYNC_WAIT_CTX_free) and (WaitCtx <> nil) then
      ASYNC_WAIT_CTX_free(WaitCtx);
    Result := nil;
  end;
end;

function RunAsyncJob(var Job: PASYNC_JOB; Func: TASYNC_start_func; 
  UserData: Pointer; WaitCtx: PASYNC_WAIT_CTX): Integer;
var
  RetVal: Integer;
begin
  Result := ASYNC_ERR;
  if not Assigned(ASYNC_start_job) or not Assigned(Func) then Exit;
  
  if WaitCtx = nil then
  begin
    if Assigned(ASYNC_WAIT_CTX_new) then
      WaitCtx := ASYNC_WAIT_CTX_new();
  end;
  
  Result := ASYNC_start_job(Job, WaitCtx, RetVal, Func, UserData, 0);
end;

function WaitForAsyncJob(Job: PASYNC_JOB; TimeoutMs: Integer): Boolean;
var
  WaitCtx: PASYNC_WAIT_CTX;
  Fds: array[0..63] of OSSL_ASYNC_FD;
  NumFds: NativeUInt;
  {$IFDEF WINDOWS}
  WaitResult: DWORD;
  {$ELSE}
  // Unix implementation would use select/poll/epoll
  {$ENDIF}
begin
  Result := False;
  if (Job = nil) or not Assigned(ASYNC_get_wait_ctx) then Exit;
  
  WaitCtx := ASYNC_get_wait_ctx(Job);
  if WaitCtx = nil then Exit;
  
  if not Assigned(ASYNC_WAIT_CTX_get_all_fds) then Exit;
  
  NumFds := Length(Fds);
  if ASYNC_WAIT_CTX_get_all_fds(WaitCtx, Fds[0], NumFds) <> 1 then Exit;
  
  if NumFds = 0 then
  begin
    // No FDs to wait on, job might already be complete
    Result := True;
    Exit;
  end;
  
  {$IFDEF WINDOWS}
  // Wait on Windows handles
  if TimeoutMs < 0 then
    WaitResult := WaitForMultipleObjects(NumFds, @Fds[0], False, INFINITE)
  else
    WaitResult := WaitForMultipleObjects(NumFds, @Fds[0], False, TimeoutMs);
    
  Result := (WaitResult >= WAIT_OBJECT_0) and 
            (WaitResult < WAIT_OBJECT_0 + NumFds);
  {$ELSE}
  // Unix path: no polling implementation is wired yet.
  // Return False for pending FDs to avoid false-positive wait success.
  Result := False;
  {$ENDIF}
end;

function IsAsyncCapable: Boolean;
begin
  Result := False;
  if Assigned(ASYNC_is_capable) then
    Result := ASYNC_is_capable() = 1;
end;

{ TAsyncJob }

constructor TAsyncJob.Create(AFunc: TASYNC_start_func; AUserData: Pointer);
begin
  inherited Create;
  FFunc := AFunc;
  FUserData := AUserData;
  FJob := nil;
  FResult := 0;
  FStatus := ASYNC_ERR;
  
  if Assigned(ASYNC_WAIT_CTX_new) then
    FWaitCtx := ASYNC_WAIT_CTX_new()
  else
    FWaitCtx := nil;
end;

destructor TAsyncJob.Destroy;
begin
  if Assigned(ASYNC_WAIT_CTX_free) and (FWaitCtx <> nil) then
    ASYNC_WAIT_CTX_free(FWaitCtx);
  inherited Destroy;
end;

function TAsyncJob.Start: Integer;
begin
  if not Assigned(ASYNC_start_job) or not Assigned(FFunc) then
  begin
    Result := ASYNC_ERR;
    Exit;
  end;
  
  FStatus := ASYNC_start_job(FJob, FWaitCtx, FResult, FFunc, FUserData, 0);
  Result := FStatus;
end;

function TAsyncJob.Pause: Boolean;
begin
  Result := False;
  if Assigned(ASYNC_pause_job) then
    Result := ASYNC_pause_job() = 1;
end;

function TAsyncJob.Resume: Integer;
begin
  if not Assigned(ASYNC_start_job) or (FJob = nil) then
  begin
    Result := ASYNC_ERR;
    Exit;
  end;
  
  FStatus := ASYNC_start_job(FJob, FWaitCtx, FResult, nil, nil, 0);
  Result := FStatus;
end;

function TAsyncJob.Wait(TimeoutMs: Integer): Boolean;
begin
  Result := WaitForAsyncJob(FJob, TimeoutMs);
end;

function TAsyncJob.GetStatus: Integer;
begin
  if Assigned(ASYNC_WAIT_CTX_get_status) and (FWaitCtx <> nil) then
    Result := ASYNC_WAIT_CTX_get_status(FWaitCtx)
  else
    Result := FStatus;
end;

{ TAsyncJobPool }

constructor TAsyncJobPool.Create(AMaxJobs: Integer);
begin
  inherited Create;
  FJobs := TList.Create;
  FMaxJobs := AMaxJobs;
  FActiveJobs := 0;
  
  // Initialize async context for the thread
  InitializeAsyncContext(AMaxJobs);
end;

destructor TAsyncJobPool.Destroy;
var
  I: Integer;
begin
  // Clean up all jobs
  for I := FJobs.Count - 1 downto 0 do
    TAsyncJob(FJobs[I]).Free;
  FJobs.Free;
  
  // Clean up async context
  CleanupAsyncContext;
  
  inherited Destroy;
end;

function TAsyncJobPool.AddJob(AFunc: TASYNC_start_func; AUserData: Pointer): TAsyncJob;
begin
  Result := nil;
  if FActiveJobs >= FMaxJobs then Exit;
  
  Result := TAsyncJob.Create(AFunc, AUserData);
  if Result.Start = ASYNC_PAUSE then
  begin
    FJobs.Add(Result);
    Inc(FActiveJobs);
  end
  else
  begin
    // Job failed to start or completed immediately
    Result.Free;
    Result := nil;
  end;
end;

function TAsyncJobPool.RemoveJob(AJob: TAsyncJob): Boolean;
var
  Index: Integer;
begin
  Result := False;
  Index := FJobs.IndexOf(AJob);
  if Index >= 0 then
  begin
    FJobs.Delete(Index);
    Dec(FActiveJobs);
    AJob.Free;
    Result := True;
  end;
end;

procedure TAsyncJobPool.WaitAll(TimeoutMs: Integer);
var
  I: Integer;
  Job: TAsyncJob;
  StartTime: QWord;
  RemainingTime: Integer;
begin
  StartTime := GetTickCount64;
  
  for I := 0 to FJobs.Count - 1 do
  begin
    Job := TAsyncJob(FJobs[I]);
    
    if TimeoutMs >= 0 then
    begin
      RemainingTime := TimeoutMs - (GetTickCount64 - StartTime);
      if RemainingTime <= 0 then Break;
      Job.Wait(RemainingTime);
    end
    else
      Job.Wait(-1);
  end;
end;

procedure TAsyncJobPool.CancelAll;
var
  I: Integer;
begin
  // Note: OpenSSL doesn't provide a direct cancel mechanism
  // Jobs need to complete or timeout naturally
  
  // Block pausing to force jobs to complete
  if Assigned(ASYNC_block_pause) then
    ASYNC_block_pause();
  
  try
    // Wait for all jobs with a short timeout
    WaitAll(100);
  finally
    if Assigned(ASYNC_unblock_pause) then
      ASYNC_unblock_pause();
  end;
  
  // Clean up remaining jobs
  for I := FJobs.Count - 1 downto 0 do
    TAsyncJob(FJobs[I]).Free;
  FJobs.Clear;
  FActiveJobs := 0;
end;

end.