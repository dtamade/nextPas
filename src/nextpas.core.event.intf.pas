unit nextpas.core.event.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.event.base;

type
  {**
   * IEventBus - 事件总线接口
   *
   * @desc
   *   进程内发布/订阅事件系统。支持优先级、取消订阅、
   *   延迟发布（队列）和即时发布。
   *}
  IEventBus = interface
    ['{D1E2F3A4-B5C6-7D8E-9F0A-1B2C3D4E5F6A}']

    {** 订阅事件（方法指针） *}
    function Subscribe(const AEventName: string; AHandler: TEventHandler;
      APriority: TEventPriority = 0): TSubscriptionID;

    {** 订阅事件（普通过程） *}
    function SubscribeProc(const AEventName: string; AHandler: TEventHandlerProc;
      APriority: TEventPriority = 0): TSubscriptionID;

    {** 取消订阅 *}
    procedure Unsubscribe(AID: TSubscriptionID);

    {** 取消指定事件的所有订阅 *}
    procedure UnsubscribeAll(const AEventName: string);

    {** 即时发布（同步调用所有处理器） *}
    procedure Emit(const AEventName: string);
    procedure EmitInt(const AEventName: string; AValue: Int64);
    procedure EmitFloat(const AEventName: string; AValue: Double);
    procedure EmitPtr(const AEventName: string; AValue: Pointer);

    {** 延迟发布（加入队列，下次 Flush 时处理） *}
    procedure Post(const AEventName: string);
    procedure PostInt(const AEventName: string; AValue: Int64);

    {** 处理队列中的所有延迟事件 *}
    procedure Flush;

    {** 清空队列 *}
    procedure ClearQueue;

    {** 查询 *}
    function GetSubscriptionCount: Integer;
    function GetQueuedCount: Integer;
  end;

implementation

end.
