{**
 * nextpas.core.collections.slotregistry - 稀疏槽登记簿
 *
 * 元素自持槽位下标，O(1) 增删：空闲栈 LIFO 复用、尾部追加、几何翻倍、
 * tail-swap 收尾、幂等增删。不线程安全（事件循环单线程登记簿形态）。
 *
 * 不变量：Items[0 .. Count-1] 为在册元素（tail-swap 保持前缀紧凑）；
 * 槽位下标约定 -1 = 未登记。调用方构造时必须把下标写成 -1。
 *
 * 消费：uses 本单元后 specialize TSlotRegistry<IFoo>。FPC 3.3.1 不能把
 * 限定名泛型当父类（`class(specialize Unit.TSlotRegistry<T>)` 报 Type
 * identifier expected），不要做薄子类别名。
 *
 * FPC 限定：实现派生接口（IFoo = interface(ISlotRegistryItem)）的类须在
 * 类声明中显式并列祖先接口，否则 QueryInterface 不识别祖先 GUID。
 *}

unit nextpas.core.collections.slotregistry;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  SLOT_REGISTRY_DEFAULT_CAPACITY = 64;

type
  { 槽位契约：Add/Remove 回写下标；-1 = 未登记/已摘除。 }
  ISlotRegistryItem = interface
    ['{F2E3D4C5-6A7B-4C8D-9E0F-1A2B3C4D5E6F}']
    function GetSlotIndex: Integer;
    procedure SetSlotIndex(const AIndex: Integer);
  end;

  generic TSlotRegistry<T: IInterface> = class
  private
    FSlots: array of T;
    FFreeSlots: array of Integer;
    FFreeCount: Integer;
    FCount: Integer;
    FInitCap: Integer;
    function GetItem(const AIndex: Integer): T;
  public
    constructor Create(const AInitCap: Integer = SLOT_REGISTRY_DEFAULT_CAPACITY);
    destructor Destroy; override;
    procedure Add(const AItem: T);
    procedure Remove(const AItem: T);
    function Count: Integer;
    function Capacity: Integer;
    property Items[const AIndex: Integer]: T read GetItem;
  end;

implementation

constructor TSlotRegistry.Create(const AInitCap: Integer);
begin
  inherited Create;
  if AInitCap < 1 then
    FInitCap := SLOT_REGISTRY_DEFAULT_CAPACITY
  else
    FInitCap := AInitCap;
end;

destructor TSlotRegistry.Destroy;
begin
  SetLength(FSlots, 0);
  SetLength(FFreeSlots, 0);
  inherited Destroy;
end;

procedure TSlotRegistry.Add(const AItem: T);
var
  LI: Integer;
  LSlot: ISlotRegistryItem;
begin
  if AItem = nil then
    Exit;
  LSlot := AItem as ISlotRegistryItem;
  LI := LSlot.GetSlotIndex;
  if (LI >= 0) and (LI < Length(FSlots)) and (FSlots[LI] = AItem) then
    Exit;
  if FFreeCount > 0 then
  begin
    Dec(FFreeCount);
    LI := FFreeSlots[FFreeCount];
    FSlots[LI] := AItem;
    LSlot.SetSlotIndex(LI);
    Inc(FCount);
    Exit;
  end;
  if FCount >= Length(FSlots) then
  begin
    if Length(FSlots) = 0 then
      SetLength(FSlots, FInitCap)
    else
      SetLength(FSlots, Length(FSlots) * 2);
  end;
  FSlots[FCount] := AItem;
  LSlot.SetSlotIndex(FCount);
  Inc(FCount);
end;

procedure TSlotRegistry.Remove(const AItem: T);
var
  LI, LTail: Integer;
begin
  if AItem = nil then
    Exit;
  LI := (AItem as ISlotRegistryItem).GetSlotIndex;
  if (LI < 0) or (LI >= Length(FSlots)) or (FSlots[LI] <> AItem) then
    Exit;
  LTail := FCount - 1;
  if LI <> LTail then
  begin
    FSlots[LI] := FSlots[LTail];
    (FSlots[LI] as ISlotRegistryItem).SetSlotIndex(LI);
  end;
  FSlots[LTail] := nil;
  (AItem as ISlotRegistryItem).SetSlotIndex(-1);
  Dec(FCount);
  if FFreeCount >= Length(FFreeSlots) then
  begin
    if Length(FFreeSlots) = 0 then
      SetLength(FFreeSlots, FInitCap)
    else
      SetLength(FFreeSlots, Length(FFreeSlots) * 2);
  end;
  FFreeSlots[FFreeCount] := LTail;
  Inc(FFreeCount);
end;

function TSlotRegistry.Count: Integer;
begin
  Result := FCount;
end;

function TSlotRegistry.Capacity: Integer;
begin
  Result := Length(FSlots);
end;

function TSlotRegistry.GetItem(const AIndex: Integer): T;
begin
  if (AIndex < 0) or (AIndex >= Length(FSlots)) then
    Result := Default(T)
  else
    Result := FSlots[AIndex];
end;

end.
