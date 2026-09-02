{**
 * np_backend_view_intf.pas
 *
 * Backend 语义视图接口 — 解耦 backend ↔ sema 直连
 *}

unit np_backend_view_intf;

{$mode objfpc}{$H+}

interface

type
  IBackendSemanticView = interface
    ['{B7E6F2A1-4C3D-4E8B-9F1A-2D3E5A6B7C9F}']
    function GetRootName: string;
    property RootName: string read GetRootName;
  end;

implementation

end.
