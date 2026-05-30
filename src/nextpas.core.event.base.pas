unit nextpas.core.event.base;

{$I nextpas.core.settings.inc}

interface

type
  {** TSubscriptionID - 订阅唯一标识符 *}
  TSubscriptionID = Integer;

  {** TEventPriority - 事件处理优先级（数值越大越先执行） *}
  TEventPriority = Integer;

  {** TEventData - 事件携带的数据（variant record） *}
  TEventDataKind = (edNone, edInt, edFloat, edString, edPointer);

  TEventData = record
    case Kind: TEventDataKind of
      edNone: ();
      edInt: (IntVal: Int64);
      edFloat: (FloatVal: Double);
      edString: (StrIdx: Integer);
      edPointer: (PtrVal: Pointer);
  end;

  {** TEventHandler - 事件处理回调 *}
  TEventHandler = procedure(const AEventName: string; const AData: TEventData) of object;
  TEventHandlerProc = procedure(const AEventName: string; const AData: TEventData);

const
  SUBSCRIPTION_INVALID: TSubscriptionID = -1;
  EVENT_MAX_SUBSCRIPTIONS = 256;
  EVENT_MAX_QUEUED = 64;

implementation

end.
