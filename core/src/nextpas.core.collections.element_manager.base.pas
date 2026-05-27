unit nextpas.core.collections.element_manager.base;

{$I nextpas.core.settings.inc}

interface

type
  generic TGenericHelper<T> = class
  public type
    PElement = ^T;
  end;

implementation

end.
