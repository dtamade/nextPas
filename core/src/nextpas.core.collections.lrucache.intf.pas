unit nextpas.core.collections.lrucache.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * ILruCache<K,V>
   *
   * @desc 最近最少使用（LRU）缓存
   * @param K 键类型（必须支持哈希和比较）
   * @param V 值类型
   * @note
   *   - 当容量满时，自动淘汰最少使用的元素
   *   - 支持 Hit/Miss 统计
   *   - O(1) 查找、插入、更新
   *   - 纯数据管理，无并发安全（职责分离）
   *}
  generic ILruCache<K, V> = interface
    ['{C3D4E5F6-A7B8-4901-CDEF-345678901BCD}']

    {**
     * Get
     *
     * @desc 获取指定键的值（访问会将该键移到 MRU 位置）
     * @param aKey 要查找的键
     * @param aValue 返回的值
     * @return Boolean 是否找到（True=命中，False=未命中）
     *}
    function Get(const aKey: K; out aValue: V): Boolean;

    {**
     * Put
     *
     * @desc 插入或更新键值对
     * @param aKey 键
     * @param aValue 值
     * @note
     *   - 如果键已存在，会更新值并将该键移到 MRU 位置
     *   - 如果容量满，会淘汰 LRU 元素
     *}
    procedure Put(const aKey: K; const aValue: V);

    {**
     * SetMaxSize
     *
     * @desc 设置缓存的最大容量
     * @param aMaxSize 新的最大容量
     * @note 如果新容量小于当前大小，会淘汰多余元素
     *}
    procedure SetMaxSize(aMaxSize: SizeUInt);

    {**
     * GetMaxSize
     *
     * @desc 获取缓存的最大容量
     * @return SizeUInt 最大容量
     *}
    function GetMaxSize: SizeUInt;

    {**
     * GetSize
     *
     * @desc 获取当前缓存大小
     * @return SizeUInt 当前大小
     *}
    function GetSize: SizeUInt;

    {**
     * GetHitCount
     *
     * @desc 获取命中次数
     * @return UInt64 命中次数
     *}
    function GetHitCount: UInt64;

    {**
     * GetMissCount
     *
     * @desc 获取未命中次数
     * @return UInt64 未命中次数
     *}
    function GetMissCount: UInt64;

    {**
     * GetHitRate
     *
     * @desc 获取命中率
     * @return Double 命中率（0.0-1.0）
     *}
    function GetHitRate: Double;

    {**
     * Clear
     *
     * @desc 清空缓存
     *}
    procedure Clear;

    {**
     * Evict
     *
     * @desc 手动淘汰 LRU 元素
     * @return Boolean 是否成功淘汰
     *}
    function Evict: Boolean;

    {**
     * EvictLeastRecent
     *
     * @desc 淘汰指定数量的元素
     * @param aCount 要淘汰的数量
     * @return SizeUInt 实际淘汰的数量
     *}
    function EvictLeastRecent(aCount: SizeUInt): SizeUInt;

    {**
     * Peek
     *
     * @desc 查看指定键的值（不更新访问顺序）
     * @param aKey 要查找的键
     * @param aValue 返回的值
     * @return Boolean 是否找到
     *}
    function Peek(const aKey: K; out aValue: V): Boolean;

    {**
     * Remove
     *
     * @desc 移除指定键
     * @param aKey 要移除的键
     * @return Boolean 是否找到并移除
     *}
    function Remove(const aKey: K): Boolean;

    {**
     * Contains
     *
     * @desc 检查是否包含指定键
     * @param aKey 要查找的键
     * @return Boolean 是否包含
     *}
    function Contains(const aKey: K): Boolean;
  end;

implementation

end.
