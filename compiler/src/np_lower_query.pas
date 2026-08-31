unit np_lower_query;

{$mode objfpc}{$H+}

interface

type
  // D分层 lower定义ILowerQuery — frontend/query 依赖 lower 接口，不依赖实现
  ILowerQuery = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Get(const AKey: string; ADefault: TObject): TObject;
    procedure Store(const AKey: string; AValue: TObject);
    procedure InvalidatePrefix(const APrefix: string);
    function ContainsValue(AValue: TObject): Boolean;
    procedure ForgetValue(AValue: TObject);
  end;

implementation

end.
