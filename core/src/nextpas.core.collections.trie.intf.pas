unit nextpas.core.collections.trie.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * ITrie<V> - 字典树接口
   *
   * @desc 字符串键的前缀树接口，支持前缀查询
   *}
  generic ITrie<V> = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']
    function Put(const aKey: string; const aValue: V): Boolean;
    function Get(const aKey: string; out aValue: V): Boolean;
    function ContainsKey(const aKey: string): Boolean;
    function Remove(const aKey: string): Boolean;
    procedure Clear;
    function HasPrefix(const aPrefix: string): Boolean;
    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
