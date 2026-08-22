unit nextpas.core.db.base;

{** @desc nextpas.core.db L3 家族：公共类型与统一错误模型。
       本单元只依赖 L0（exception），是整个 db 家族的依赖根；
       禁止 uses 任何具体后端单元（sqlite/pg）。

       错误模型：适配层把后端异常转译为 EDbError，双码位并存——
       适用哪个后端就填哪个字段，不做跨后端语义归一（无真实消费
       需求前不发明映射表）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  { 数据库后端种类 }
  TDbKind = (
    dbkSqlite,
    dbkPostgres
  );

  { 统一列类型（对齐两后端原生分类的公共最小集） }
  TDbColumnType = (
    dbcNull,
    dbcInteger,
    dbcFloat,
    dbcText,
    dbcBlob
  );

  {** 统一数据库错误。
      Message 恒为后端原始消息；字段按引发后端填充：
      - sqlite：BackendCode / ExtendedCode 有值，SqlState 等空串
      - postgres：SqlState / Severity / Detail 有值，码位字段 0 *}
  EDbError = class(ENextPasError)
  private
    FBackend: TDbKind;
    FBackendCode: Integer;
    FExtendedCode: Integer;
    FSqlState: string;
    FSeverity: string;
    FDetail: string;
  public
    constructor CreateSimple(const ABackend: TDbKind; const AMessage: string); overload;
    constructor CreateSqlite(const ACode, AExtendedCode: Integer;
      const AMessage: string); overload;
    constructor CreatePg(const ASqlState, ASeverity, ADetail,
      AMessage: string); overload;

    property Backend: TDbKind read FBackend;
    { sqlite 结果码；非 sqlite 引发时为 0 }
    property BackendCode: Integer read FBackendCode;
    { sqlite extended code；否则 0 }
    property ExtendedCode: Integer read FExtendedCode;
    { pg SQLSTATE；否则空串 }
    property SqlState: string read FSqlState;
    property Severity: string read FSeverity;
    property Detail: string read FDetail;
  end;

  { 后端能力未覆盖（如当前版本 pg 侧不支持的绑定形态）。
    fail-closed：宁可报不支持也不静默降级。 }
  EDbNotSupported = class(EDbError);

implementation

constructor EDbError.CreateSimple(const ABackend: TDbKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := ABackend;
end;

constructor EDbError.CreateSqlite(const ACode, AExtendedCode: Integer;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := dbkSqlite;
  FBackendCode := ACode;
  FExtendedCode := AExtendedCode;
end;

constructor EDbError.CreatePg(const ASqlState, ASeverity, ADetail,
  AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := dbkPostgres;
  FSqlState := ASqlState;
  FSeverity := ASeverity;
  FDetail := ADetail;
end;

end.
