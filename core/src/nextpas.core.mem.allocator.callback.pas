unit nextpas.core.mem.allocator.callback;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.allocator.base;

type
  // 自定义分配器的回调类型（与回调分配器同域，避免 base 膨胀）
  TGetMemCallback     = function(ASize: SizeUInt): Pointer;
  TAllocMemCallback   = function(ASize: SizeUInt): Pointer;
  TReallocMemCallback = function(ADst: Pointer; ASize: SizeUInt): Pointer;
  TFreeMemCallback    = procedure(ADst: Pointer);

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
    function  DoGetMem(ASize: SizeUInt): Pointer; override;
    function  DoAllocMem(ASize: SizeUInt): Pointer; override;
    function  DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
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
    raise EArgumentNil.Create('TCallbackAllocator.Create: aGetMem, aAllocMem, aReallocMem, aFreeMem cannot be nil.');
  FGetMemCallback     := aGetMem;
  FAllocMemCallback   := aAllocMem;
  FReallocMemCallback := aReallocMem;
  FFreeMemCallback    := aFreeMem;
end;

function TCallbackAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FGetMemCallback(ASize)
end;

function TCallbackAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FAllocMemCallback(ASize)
end;

function TCallbackAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := FReallocMemCallback(ADst, ASize)
end;

procedure TCallbackAllocator.DoFreeMem(ADst: Pointer);
begin
  FFreeMemCallback(ADst)
end;

function CreateCallbackAllocator(aGetMem: TGetMemCallback;
  aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback): TCallbackAllocator;
begin
  Result := TCallbackAllocator.Init(aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

end.
