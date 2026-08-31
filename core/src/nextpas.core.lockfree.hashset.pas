unit nextpas.core.lockfree.hashset;
{**
 * @desc Concurrent HashSet based on ShardedHashMap.
 *
 * @note This is a thin wrapper around TShardedHashMap that uses
 *       a fixed value (True) for all entries, providing set semantics.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.hashmap;

type
  {**
   * 并发 HashSet。
   *
   * 基于 TShardedHashMap 实现，所有值固定为 True。
   * 支持 Insert/Remove/Contains/Count/Clear。
   *
   * @constraints
   *   - TKey 必须支持哈希和相等比较
   *   - TKey 必须是 unmanaged 类型
   *   - 所有公共方法是线程安全的
   *}
  generic TConcurrentHashSetImpl<TKey> = class
  private type
    TMap = specialize TShardedHashMap<TKey, Boolean>;
  private
    FMap: TMap;
  public
    {** @desc 创建并发 HashSet
      @param AInitialCapacity 底层 HashMap 的初始容量 }
    constructor Create(const AInitialCapacity: Integer = HASHMAP_DEFAULT_CAPACITY);
    destructor Destroy; override;

    {** @desc 插入元素
      @param AKey 要插入的键
      @note 如果键已存在，则无操作 }
    procedure Insert(const AKey: TKey);

    {** @desc 删除元素
      @param AKey 要删除的键
      @return 如果删除成功返回 True }
    function Remove(const AKey: TKey): Boolean;

    {** @desc 检查元素是否存在
      @param AKey 要检查的键
      @return 如果存在返回 True }
    function Contains(const AKey: TKey): Boolean; inline;

    {** @desc 获取元素数量
      @return 元素数量 }
    function Count: PtrUInt; inline;

    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 关闭：转发到底层 HashMap.Close }
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

  generic TConcurrentHashSet<TKey> = class(specialize TConcurrentHashSetImpl<TKey>)
  end;

implementation

uses
  nextpas.core.errors;

constructor TConcurrentHashSetImpl.Create(const AInitialCapacity: Integer);
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TConcurrentHashSet: TKey must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FMap := TMap.Create(AInitialCapacity);
end;

destructor TConcurrentHashSetImpl.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TConcurrentHashSetImpl.Insert(const AKey: TKey);
begin
  FMap.Insert(AKey, True);
end;

function TConcurrentHashSetImpl.Remove(const AKey: TKey): Boolean;
begin
  Result := FMap.Remove(AKey);
end;

function TConcurrentHashSetImpl.Contains(const AKey: TKey): Boolean; inline;
var
  LDummy: Boolean;
begin
  Result := FMap.Find(AKey, LDummy);
end;

function TConcurrentHashSetImpl.Count: PtrUInt; inline;
begin
  Result := FMap.Count;
end;

procedure TConcurrentHashSetImpl.Clear;
begin
  FMap.Clear;
end;

procedure TConcurrentHashSetImpl.Close;
begin
  FMap.Close;
end;

function TConcurrentHashSetImpl.IsClosed: Boolean; inline;
begin
  Result := FMap.IsClosed;
end;

end.
