unit nextpas.core.mem.allocator.callback_allocator;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  {$IFDEF FAFAFA_CORE_CONTRACTS}
  nextpas.core.base,
  {$ENDIF}
  nextpas.core.mem.allocator.base;

type
  // 自定义分配器的回调类型（与回调分配器同域，避免 base 膨胀）
  TGetMemCallback     = function(aSize: SizeUInt): Pointer;
  TAllocMemCallback   = function(aSize: SizeUInt): Pointer;
  TReallocMemCallback = function(aDst: Pointer; aSize: SizeUInt): Pointer;
  TFreeMemCallback    = procedure(aDst: Pointer);

  {**
   * TCallbackAllocator
   * @desc 使用用户提供的回调函数进行内存管理的 IAllocator 具体类
   *}
  TCallbackAllocator = class(TAllocator)
  private
    FGetMemCallback:     TGetMemCallback;
    FAllocMemCallback:   TAllocMemCallback;
    FReallocMemCallback: TReallocMemCallback;
    FFreeMemCallback:    TFreeMemCallback;
  protected
    function  DoGetMem(aSize: SizeUInt): Pointer; override;
    function  DoAllocMem(aSize: SizeUInt): Pointer; override;
    function  DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    constructor Init(aGetMem: TGetMemCallback; aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback);
  end;

function CreateCallbackAllocator(aGetMem: TGetMemCallback;
                                 aAllocMem: TAllocMemCallback;
                                 aReallocMem: TReallocMemCallback;
                                 aFreeMem: TFreeMemCallback): TCallbackAllocator;

implementation

constructor TCallbackAllocator.Init(aGetMem: TGetMemCallback; aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback);
begin
  inherited Create;
  if (aGetMem = nil) or (aAllocMem = nil) or (aReallocMem = nil) or (aFreeMem = nil) then
  begin
    {$IFDEF FAFAFA_CORE_CONTRACTS}
    raise EArgumentNil.Create('TCallbackAllocator.Create: aGetMem, aAllocMem, aReallocMem, aFreeMem cannot be nil.');
    {$ENDIF}
  end;
  FGetMemCallback     := aGetMem;
  FAllocMemCallback   := aAllocMem;
  FReallocMemCallback := aReallocMem;
  FFreeMemCallback    := aFreeMem;
end;

function TCallbackAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := FGetMemCallback(aSize)
end;

function TCallbackAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := FAllocMemCallback(aSize)
end;

function TCallbackAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := FReallocMemCallback(aDst, aSize)
end;

procedure TCallbackAllocator.DoFreeMem(aDst: Pointer);
begin
  FFreeMemCallback(aDst)
end;

function CreateCallbackAllocator(aGetMem: TGetMemCallback;
  aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback): TCallbackAllocator;
begin
  Result := TCallbackAllocator.Init(aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

end.
