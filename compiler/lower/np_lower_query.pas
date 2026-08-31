{
  np_lower_query.pas — Lower Query Interface (D 分层)

  D 层级下沉查询抽象：lower 层定义契约，前端 QueryDatabase 适配，
  实现 interface 去 uses 耦合（lower 不直接 uses 前端）。
}
unit np_lower_query;

{$mode objfpc}{$H+}

interface

type
  ILowerQuery = interface
    ['{A7F3C2E1-8B4D-4E9A-9F2C-1D3E5A6B7C8D}']
    function QueryGet(const AKey: string; ADefault: TObject): TObject;
    procedure QueryStore(const AKey: string; AValue: TObject);
  end;

implementation

end.
