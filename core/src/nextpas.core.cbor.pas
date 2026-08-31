unit nextpas.core.cbor;

{** @desc RFC 8949 CBOR 编解码（确定性子集，L2 序列化格式家族，json/yaml/toml 同层）。
       - 解码：definite lengths only——indefinite（ai=31）、tag（major 6）、
         保留 ai（28..30）一律拒绝（fail-closed）；深度/节点数上限防恶意输入
         放大；根之后残留字节按错误处理（严格消费，WebAuthn 场景要求精确）。
       - 整数域收敛 Int64：major 0 幅度 > High(Int64)、major 1 结果越界报错
         （RFC 全域 uint64 有意收窄；COSE/WebAuthn 消费场景不需要更宽，
         文档化的子集边界）。
       - 文本串零拷贝（TStringView 指向输入缓冲区），UTF-8 良构性不校验——
         与 json 家族同口径；字节串由文档持有副本。
       - 错误面走 json 先例：CborParse 返回文档句柄 HasError/Error，不抛异常
         （不可信输入解析属边界处理）；builder 契约违例属编程错误走异常。
       - 编码：确定性紧凑输出（definite length），builder 形态供已知结构组装。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view;

const
  { 容量上限：恶意输入不放大（嵌套深度与节点总量）。 }
  cCborMaxDepth = 32;
  cCborMaxNodes = 65536;

type
{ ===== 确定性编码 builder（definite lengths；紧凑输出）===== }

  ICborBuilder = interface
    ['{7E4C2A91-3B58-4D06-9F12-CB0B0B000002}']
    procedure Uint(const AValue: UInt64);
    { AFinal 为最终负值（< 0），按 RFC 规则编码 -1-AFinal。 }
    procedure NegInt(const AFinal: Int64);
    { 符号分派便利：≥ 0 走 Uint，< 0 走 NegInt。 }
    procedure Int(const AValue: Int64);
    procedure Bytes(const AValue: TBytes);
    procedure Text(const AValue: string);
    procedure Bool(const AValue: Boolean);
    procedure Null;
    { 恒以 float64（ai 27）确定性编码。 }
    procedure Float(const AValue: Double);
    { definite-length 容器头：随后恰好 AItemCount 个元素 / APairCount 对。 }
    procedure BeginArray(const AItemCount: SizeUInt);
    procedure BeginMap(const APairCount: SizeUInt);
    function ToBytes: TBytes;
  end;

  function CborBuilder: ICborBuilder;

type
  TCborKind = (
    cbkUint,     { major 0：非负整数（≤ High(Int64)）}
    cbkNegInt,   { major 1：负整数（≥ Low(Int64)；AsInt 直接给最终值）}
    cbkBytes,    { major 2：字节串 }
    cbkText,     { major 3：文本串（输入上的 UTF-8 字节视图）}
    cbkArray,    { major 4 }
    cbkMap,      { major 5：PairCount 对；键任意 kind（int 键 GetInt /
                   text 键 Get 线性查，重复键首匹配）}
    cbkBool,     { major 7 additional info 20/21 }
    cbkNull,     { major 7 ai 22（null）/ 23（undefined 收敛同义）}
    cbkReal      { major 7 ai 25(half)/26(single)/27(double) → AsReal }
  );

  TCborError = record
    Message: string;
    Offset: SizeUInt;
  end;

const
  cCborNoIndex = UInt32($FFFFFFFF);

type
  { 内部节点（公开载体供 TCborValue 零成本借用，镜像 json.types.TJsonNode）：
    容器经 FirstChild + 兄弟链 Next 串联（数组 = 元素序列；
    map = 键值交错序列）。 }
  TCborNode = record
    Kind: TCborKind;
    Next: UInt32;         { 兄弟节点下标；cCborNoIndex = 无 }
    IntVal: Int64;
    RealVal: Double;
    View: TStringView;    { text 零拷贝 }
    BlobIndex: Int32;     { bytes → TCborDocument.Blobs 下标 }
    BoolVal: Boolean;
    FirstChild: UInt32;   { 容器首个子节点下标 }
    Count: UInt32;        { 直接子节点数（map = 对数×2）}
  end;
  PCborNode = ^TCborNode;

  { 解析输出 arena：TCborValue 借用其节点数组；经堆分配 + 接口包装管理寿命。
    字段 private——消费方只经 ICborDocument / TCborValue 访问。 }
  PCborDocument = ^TCborDocument;
  TCborDocument = record
  private
    FNodes: array of TCborNode;
    FBlobs: array of TBytes;
    FHasError: Boolean;
    FErr: TCborError;
    FRootEnd: SizeUInt;
    function GetNode(const AIdx: UInt32): PCborNode; inline;
  public
    procedure Init;
    function AddNode(const ANode: TCborNode): UInt32;
    function AddBlob(const AData: PByte; const ALen: SizeUInt): Int32;
    procedure SetError(const AOffset: SizeUInt; const AMessage: string);
    function HasError: Boolean; inline;
    function Error: TCborError; inline;
    function RootIndex: UInt32; inline;
    { 根 item 结束偏移（相对传入缓冲；前缀解析的消费长度语义） }
    function RootEnd: SizeUInt; inline;
    property Node[AIdx: UInt32]: PCborNode read GetNode;
  end;

  { 借用视图：16 字节记录（文档指针 + 节点下标），访问零分配。
    寿命：所属 ICborDocument 存活期内有效；invalid 值给安全缺省。 }
  TCborValue = record
  private
    function NodePtr: PCborNode; inline;
  public
    FDoc: PCborDocument;
    FIdx: UInt32;
  public
    class function Create(const ADoc: PCborDocument;
      const AIdx: UInt32): TCborValue; static; inline;
    function IsValid: Boolean; inline;      { False = 缺键 / 越界 / 文档有错 }
    function Kind: TCborKind; inline;       { invalid 收敛 cbkNull }
    function IsInt: Boolean; inline;        { cbkUint 或 cbkNegInt }
    function IsBytes: Boolean; inline;
    function IsText: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsMap: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsNull: Boolean; inline;
    function IsReal: Boolean; inline;
    function AsInt: Int64;                  { uint/negint 最终值；其余 0 }
    function AsBytes: TBytes;               { bytes 副本；其余空 }
    function AsStr: TStringView;            { text 视图；其余空视图 }
    function AsStrStr: string;              { text → string 便利 }
    function AsBool: Boolean;               { 非 bool = False }
    function AsReal: Double;                { 非 real = 0.0 }
    function ChildCount: SizeUInt; inline;  { array 元素数；map = 对数×2 }
    function ChildAt(const AIndex: SizeUInt): TCborValue;
    function PairCount: SizeUInt; inline;   { map 对数；非 map = 0 }
    function PairKeyAt(const APairIndex: SizeUInt): TCborValue;
    function PairValueAt(const APairIndex: SizeUInt): TCborValue;
    { text 键线性查找（首匹配）；缺失 / 非 map / 文档有错返回 Invalid。 }
    function Get(const ATextKey: string): TCborValue; overload;
    function Get(const ATextKey: TStringView): TCborValue; overload;
    { 整数键线性查找（COSE 标签含负数，如 -1/-2/-3）。 }
    function GetInt(const AKey: Int64): TCborValue;
  end;

  ICborDocument = interface
    ['{7E4C2A91-3B58-4D06-9F12-CB0B0B000001}']
    function HasError: Boolean;
    function Error: TCborError;
    { 解析失败时返回 Invalid 值。 }
    function Root: TCborValue;
  end;

  { 解析不可信字节：永不抛异常；HasError 判定（根之后残留字节 = 错误）。 }
  function CborParse(const AData: TBytes): ICborDocument; overload;
  function CborParse(const AData: PByte; const ASize: SizeUInt): ICborDocument; overload;

type
  { 前缀解析结果：Consumed = item 从起点占用的字节数；Doc 为该 item 的
    DOM 视图。失败：Consumed=0 且 Doc.HasError=True。寿命：Doc 存活期内
    输入缓冲必须有效（借用视图纪律，同 TCborValue）。 }
  TCborPrefixResult = record
    Consumed: SizeUInt;
    Doc: ICborDocument;
  end;

{ 前缀解析：AData[AOffset] 起读恰好一个完整 item，容许其后尾随字节
  （混合格式容器——WebAuthn authenticatorData 内嵌 COSE 公钥等场景）。
  AOffset 越界 / 恶性输入：Consumed=0、HasError=True。 }
function CborParsePrefix(const AData: TBytes;
  const AOffset: SizeUInt): TCborPrefixResult;



implementation

uses
  nextpas.core.errors;

{ ===== TCborDocument ===== }

procedure TCborDocument.Init;
begin
  FNodes := nil;
  FBlobs := nil;
  FHasError := False;
  FErr := Default(TCborError);
  FRootEnd := 0;
end;

function TCborDocument.GetNode(const AIdx: UInt32): PCborNode;
begin
  if AIdx < UInt32(Length(FNodes)) then
    Result := @FNodes[AIdx]
  else
    Result := nil;
end;

function TCborDocument.AddNode(const ANode: TCborNode): UInt32;
var
  LN: SizeUInt;
begin
  LN := Length(FNodes);
  if LN >= cCborMaxNodes then
  begin
    SetError(0, 'node limit exceeded');
    Result := cCborNoIndex;
    Exit;
  end;
  SetLength(FNodes, LN + 1);
  FNodes[LN] := ANode;
  Result := UInt32(LN);
end;

function TCborDocument.AddBlob(const AData: PByte; const ALen: SizeUInt): Int32;
var
  LB: SizeUInt;
begin
  LB := Length(FBlobs);
  SetLength(FBlobs, LB + 1);
  SetLength(FBlobs[LB], ALen);
  if ALen > 0 then
    Move(AData^, FBlobs[LB][0], ALen);
  Result := Int32(LB);
end;

procedure TCborDocument.SetError(const AOffset: SizeUInt; const AMessage: string);
begin
  if not FHasError then
  begin
    FHasError := True;
    FErr.Message := AMessage;
    FErr.Offset := AOffset;
  end;
end;

function TCborDocument.HasError: Boolean;
begin
  Result := FHasError;
end;

function TCborDocument.Error: TCborError;
begin
  Result := FErr;
end;

function TCborDocument.RootIndex: UInt32;
begin
  if (not FHasError) and (Length(FNodes) > 0) then
    Result := 0
  else
    Result := cCborNoIndex;
end;

function TCborDocument.RootEnd: SizeUInt;
begin
  Result := FRootEnd;
end;

{ ===== 解析器 ===== }

type
  TCborParser = class
  private
    FData: PByte;
    FSize: SizeUInt;
    FPos: SizeUInt;
    FDoc: PCborDocument;
    function TakeByte(out AB: Byte): Boolean;
    function TakeRaw(ALen: SizeUInt; out ADst: PByte): Boolean;
    function ReadHead(out AMajor: Byte; out AArgument: UInt64;
      out AAi: Byte): Boolean;
    function ParseValue(const ADepth: Integer): UInt32;
    function DecodeHalfFloat(const ABits: Word): Double;
  public
    constructor Create(const AData: PByte; const ASize: SizeUInt;
      const ADoc: PCborDocument);
    procedure Run(const AAllowTrailing: Boolean);
  end;

constructor TCborParser.Create(const AData: PByte; const ASize: SizeUInt;
  const ADoc: PCborDocument);
begin
  inherited Create;
  FData := AData;
  FSize := ASize;
  FPos := 0;
  FDoc := ADoc;
end;

function TCborParser.TakeByte(out AB: Byte): Boolean;
begin
  if FPos < FSize then
  begin
    AB := FData[FPos];
    FPos := FPos + 1;
    Result := True;
  end
  else
  begin
    AB := 0;
    Result := False;
  end;
end;

function TCborParser.TakeRaw(ALen: SizeUInt; out ADst: PByte): Boolean;
begin
  if ALen <= FSize - FPos then
  begin
    ADst := @FData[FPos];
    FPos := FPos + ALen;
    Result := True;
  end
  else
  begin
    ADst := nil;
    Result := False;
  end;
end;

{ 头字节：major = b shr 5，additional info = b and $1F；ai 24..27 携带
  1/2/4/8 字节大端参数，28..30 保留、31 indefinite——均拒绝。 }
function TCborParser.ReadHead(out AMajor: Byte; out AArgument: UInt64;
  out AAi: Byte): Boolean;
var
  LB, LAi, LN, I: Byte;
begin
  AArgument := 0;
  AAi := 0;
  if not TakeByte(LB) then
  begin
    FDoc^.SetError(FPos, 'truncated head');
    Exit(False);
  end;
  AMajor := LB shr 5;
  LAi := LB and $1F;
  AAi := LAi;
  if LAi < 24 then
  begin
    AArgument := LAi;
    Exit(True);
  end;
  case LAi of
    24: LN := 1;
    25: LN := 2;
    26: LN := 4;
    27: LN := 8;
  else
    if LAi = 31 then
      FDoc^.SetError(FPos - 1, 'indefinite length not supported')
    else
      FDoc^.SetError(FPos - 1, 'reserved additional info');
    Exit(False);
  end;
  for I := 1 to LN do
  begin
    if not TakeByte(LB) then
    begin
      FDoc^.SetError(FPos, 'truncated argument');
      Exit(False);
    end;
    AArgument := (AArgument shl 8) or LB;
  end;
  Result := True;
end;

{ IEEE 754 binary16 → Double：纯位构造（不引 math 单元）。
  e=0 子正规 = f × 2^-24；e=31 全零尾数 = ±Inf、非零 = NaN；
  正规 = (1+f/1024) × 2^(e-15)，直接拼 double 位（exp 偏置 1023）。 }
function TCborParser.DecodeHalfFloat(const ABits: Word): Double;
var
  LSign, LExp, LFrac: Word;
  LBits: UInt64;
begin
  LSign := (ABits shr 15) and 1;
  LExp := (ABits shr 10) and $1F;
  LFrac := ABits and $3FF;
  if LExp = 31 then
    if LFrac = 0 then
      LBits := (UInt64(LSign) shl 63) or UInt64($7FF0000000000000)
    else
      LBits := (UInt64(LSign) shl 63) or UInt64($7FF0000000000000)
        or (UInt64(LFrac) shl 42)
  else if (LExp = 0) and (LFrac = 0) then
    LBits := UInt64(LSign) shl 63                                  { ±0.0 }
  else if LExp = 0 then
  begin
    Result := LFrac * 5.9604644775390625e-8;                       { 2^-24 }
    if LSign = 1 then
      Result := -Result;
    Exit;
  end
  else
    LBits := (UInt64(LSign) shl 63)
      or (UInt64(LExp - 15 + 1023) shl 52)
      or (UInt64(LFrac) shl 42);
  Move(LBits, Result, SizeOf(Result));
end;

function TCborParser.ParseValue(const ADepth: Integer): UInt32;
var
  LMajor: Byte;
  LArg: UInt64;
  LAiHead: Byte;
  LNode: TCborNode;
  LRaw: PByte;
  LLimit: SizeUInt;
  LPrev, LChild, LSelf: UInt32;
  LI: SizeUInt;
  LBits: UInt64;
  LSingle: Single;
begin
  Result := cCborNoIndex;
  if ADepth > cCborMaxDepth then
  begin
    FDoc^.SetError(FPos, 'depth limit exceeded');
    Exit;
  end;
  if not ReadHead(LMajor, LArg, LAiHead) then
    Exit;
  LNode := Default(TCborNode);
  LNode.Next := cCborNoIndex;
  LNode.BlobIndex := -1;
  case LMajor of
    0:
      begin
        if LArg > UInt64(High(Int64)) then
        begin
          FDoc^.SetError(FPos, 'uint exceeds Int64 domain');
          Exit;
        end;
        LNode.Kind := cbkUint;
        LNode.IntVal := Int64(LArg);
      end;
    1:
      begin
        if LArg > UInt64(High(Int64)) then
        begin
          FDoc^.SetError(FPos, 'negint exceeds Int64 domain');
          Exit;
        end;
        LNode.Kind := cbkNegInt;
        LNode.IntVal := -1 - Int64(LArg);
      end;
    2:
      begin
        if LArg > UInt64(FSize - FPos) then
        begin
          FDoc^.SetError(FPos, 'byte length exceeds input');
          Exit;
        end;
        if not TakeRaw(SizeUInt(LArg), LRaw) then
        begin
          FDoc^.SetError(FPos, 'truncated bytes');
          Exit;
        end;
        LNode.Kind := cbkBytes;
        LNode.Count := UInt32(LArg);
        LNode.BlobIndex := FDoc^.AddBlob(LRaw, SizeUInt(LArg));
      end;
    3:
      begin
        if LArg > UInt64(FSize - FPos) then
        begin
          FDoc^.SetError(FPos, 'text length exceeds input');
          Exit;
        end;
        if not TakeRaw(SizeUInt(LArg), LRaw) then
        begin
          FDoc^.SetError(FPos, 'truncated text');
          Exit;
        end;
        LNode.Kind := cbkText;
        LNode.View := TStringView.Create(PAnsiChar(LRaw), SizeUInt(LArg));
      end;
    4, 5:
      begin
        if LMajor = 4 then
        begin
          LNode.Kind := cbkArray;
          LNode.Count := UInt32(LArg);
          LLimit := SizeUInt(LArg);
        end
        else
        begin
          LNode.Kind := cbkMap;
          if LArg > UInt64(High(UInt32) div 2) then
          begin
            FDoc^.SetError(FPos, 'map pair count overflow');
            Exit;
          end;
          LNode.Count := UInt32(LArg) * 2;
          LLimit := SizeUInt(LNode.Count);
        end;
        { 父节点先落位（FirstChild 随子节点解析回填），兄弟链显式串联——
          子代嵌套不破坏直接子节点的可达性。 }
        LNode.FirstChild := cCborNoIndex;
        LSelf := FDoc^.AddNode(LNode);
        if LSelf = cCborNoIndex then
          Exit;
        LPrev := cCborNoIndex;
        LI := 0;
        while LI < LLimit do                    { SizeUInt：避免 0-1 回绕 }
        begin
          LChild := ParseValue(ADepth + 1);
          if LChild = cCborNoIndex then
            Exit;
          if LPrev = cCborNoIndex then
            FDoc^.Node[LSelf]^.FirstChild := LChild
          else
            FDoc^.Node[LPrev]^.Next := LChild;
          LPrev := LChild;
          LI := LI + 1;
        end;
        Result := LSelf;
        Exit;
      end;
    6:
      begin
        FDoc^.SetError(FPos, 'tags not supported (subset)');
        Exit;
      end;
  else
    { major 7：简单值与浮点。参数字节已由 ReadHead 收进 LArg；
      ai 区分语义——24（两字节 simple 形式）非确定性编码，拒绝。 }
    case LAiHead of
      25:
        begin
          LNode.Kind := cbkReal;
          LNode.RealVal := DecodeHalfFloat(Word(LArg and $FFFF));
        end;
      26:
        begin
          LBits := LArg and $FFFFFFFF;
          Move(LBits, LSingle, SizeOf(LSingle));
          LNode.Kind := cbkReal;
          LNode.RealVal := LSingle;
        end;
      27:
        begin
          LNode.Kind := cbkReal;
          Move(LArg, LNode.RealVal, SizeOf(LNode.RealVal));
        end;
      0..23:
        case LArg of
          20, 21:
            begin
              LNode.Kind := cbkBool;
              LNode.BoolVal := LArg = 21;
            end;
          22, 23:
            LNode.Kind := cbkNull;
        else
          FDoc^.SetError(FPos, 'unsupported simple value');
          Exit;
        end;
    else
      FDoc^.SetError(FPos, 'unsupported simple value');
      Exit;
    end;
  end;
  Result := FDoc^.AddNode(LNode);
end;

procedure TCborParser.Run(const AAllowTrailing: Boolean);
var
  LRoot: UInt32;
begin
  LRoot := ParseValue(1);
  if (LRoot = cCborNoIndex) and (not FDoc^.HasError) then
  begin
    FDoc^.SetError(FPos, 'no root value');
    Exit;
  end;
  if FDoc^.HasError then
    Exit;
  { 根 item 结束处先落位：前缀解析（AAllowTrailing）据此报告消费长度 }
  FDoc^.FRootEnd := FPos;
  if (FPos <> FSize) and (not AAllowTrailing) then
    FDoc^.SetError(FPos, 'trailing bytes after root');
end;

{ ===== 文档句柄 ===== }

type
  TCborDocumentImpl = class(TInterfacedObject, ICborDocument)
  private
    FDoc: PCborDocument;
  public
    constructor Create(const AData: PByte; const ASize: SizeUInt);
    { 接管已解析完的文档记录（CborParsePrefix 自管解析流程时用） }
    constructor CreateAdopt(const ARec: PCborDocument);
    destructor Destroy; override;
    function HasError: Boolean;
    function Error: TCborError;
    function Root: TCborValue;
  end;

constructor TCborDocumentImpl.CreateAdopt(const ARec: PCborDocument);
begin
  inherited Create;
  FDoc := ARec;
end;

constructor TCborDocumentImpl.Create(const AData: PByte; const ASize: SizeUInt);
var
  LParser: TCborParser;
begin
  inherited Create;
  New(FDoc);
  FDoc^.Init;
  if (ASize = 0) or (AData = nil) then
  begin
    FDoc^.SetError(0, 'empty input');
    Exit;
  end;
  LParser := TCborParser.Create(AData, ASize, FDoc);
  try
    LParser.Run(False);
  finally
    LParser.Free;
  end;
end;

destructor TCborDocumentImpl.Destroy;
begin
  if FDoc <> nil then
  begin
    Dispose(FDoc);
    FDoc := nil;
  end;
  inherited Destroy;
end;

function TCborDocumentImpl.HasError: Boolean;
begin
  Result := FDoc^.HasError;
end;

function TCborDocumentImpl.Error: TCborError;
begin
  Result := FDoc^.Error;
end;

function TCborDocumentImpl.Root: TCborValue;
begin
  Result := TCborValue.Create(FDoc, FDoc^.RootIndex);
end;

function CborParse(const AData: TBytes): ICborDocument;
begin
  if Length(AData) = 0 then
    Result := CborParse(PByte(nil), 0)
  else
    Result := CborParse(@AData[0], SizeUInt(Length(AData)));
end;

function CborParse(const AData: PByte; const ASize: SizeUInt): ICborDocument;
begin
  Result := TCborDocumentImpl.Create(AData, ASize);
end;

function CborParsePrefix(const AData: TBytes;
  const AOffset: SizeUInt): TCborPrefixResult;
var
  LRec: PCborDocument;
  LParser: TCborParser;
  LSize: SizeUInt;
begin
  LSize := SizeUInt(Length(AData));
  New(LRec);
  LRec^.Init;
  LParser := nil;
  if AOffset < LSize then
  begin
    LParser := TCborParser.Create(@AData[AOffset], LSize - AOffset, LRec);
    try
      LParser.Run(True);
    finally
      LParser.Free;
    end;
  end
  else
    LRec^.SetError(AOffset, 'offset beyond input');
  if LRec^.HasError then
    Result.Consumed := 0
  else
    Result.Consumed := LRec^.RootEnd;
  Result.Doc := TCborDocumentImpl.CreateAdopt(LRec);
end;

{ ===== TCborValue ===== }

class function TCborValue.Create(const ADoc: PCborDocument;
  const AIdx: UInt32): TCborValue;
begin
  Result.FDoc := ADoc;
  Result.FIdx := AIdx;
end;

function TCborValue.IsValid: Boolean;
begin
  Result := (FDoc <> nil) and (not FDoc^.HasError) and (FIdx <> cCborNoIndex);
end;

function TCborValue.NodePtr: PCborNode;
begin
  if (FDoc <> nil) and (not FDoc^.HasError) and (FIdx <> cCborNoIndex) then
    Result := FDoc^.Node[FIdx]
  else
    Result := nil;
end;

function TCborValue.Kind: TCborKind;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  if LN = nil then
    Result := cbkNull
  else
    Result := LN^.Kind;
end;

function TCborValue.IsInt: Boolean;
begin
  Result := Kind in [cbkUint, cbkNegInt];
end;

function TCborValue.IsBytes: Boolean;
begin
  Result := Kind = cbkBytes;
end;

function TCborValue.IsText: Boolean;
begin
  Result := Kind = cbkText;
end;

function TCborValue.IsArray: Boolean;
begin
  Result := Kind = cbkArray;
end;

function TCborValue.IsMap: Boolean;
begin
  Result := Kind = cbkMap;
end;

function TCborValue.IsBool: Boolean;
begin
  Result := Kind = cbkBool;
end;

function TCborValue.IsNull: Boolean;
begin
  Result := Kind = cbkNull;
end;

function TCborValue.IsReal: Boolean;
begin
  Result := Kind = cbkReal;
end;

function TCborValue.AsInt: Int64;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  if (LN <> nil) and (LN^.Kind in [cbkUint, cbkNegInt]) then
    Result := LN^.IntVal
  else
    Result := 0;
end;

function TCborValue.AsBytes: TBytes;
var
  LN: PCborNode;
begin
  Result := nil;
  LN := NodePtr;
  if (LN <> nil) and (LN^.Kind = cbkBytes) and (LN^.BlobIndex >= 0) then
    Result := Copy(FDoc^.FBlobs[LN^.BlobIndex], 0,
      Length(FDoc^.FBlobs[LN^.BlobIndex]));
end;

function TCborValue.AsStr: TStringView;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  if (LN <> nil) and (LN^.Kind = cbkText) then
    Result := LN^.View
  else
    Result := TStringView.Empty;
end;

function TCborValue.AsStrStr: string;
begin
  Result := AsStr.ToString;
end;

function TCborValue.AsBool: Boolean;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  Result := (LN <> nil) and (LN^.Kind = cbkBool) and LN^.BoolVal;
end;

function TCborValue.AsReal: Double;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  if (LN <> nil) and (LN^.Kind = cbkReal) then
    Result := LN^.RealVal
  else
    Result := 0.0;
end;

function TCborValue.ChildCount: SizeUInt;
var
  LN: PCborNode;
begin
  LN := NodePtr;
  if (LN <> nil) and (LN^.Kind in [cbkArray, cbkMap]) then
    Result := LN^.Count
  else
    Result := 0;
end;

function TCborValue.ChildAt(const AIndex: SizeUInt): TCborValue;
var
  LN: PCborNode;
  LCur: UInt32;
  LI: SizeUInt;
begin
  Result := Default(TCborValue);
  LN := NodePtr;
  if LN = nil then
    Exit;
  LCur := LN^.FirstChild;
  LI := 0;
  while (LCur <> cCborNoIndex) and (LI <= AIndex) do
  begin
    if LI = AIndex then
      Exit(TCborValue.Create(FDoc, LCur));
    LCur := FDoc^.Node[LCur]^.Next;
    LI := LI + 1;
  end;
end;

function TCborValue.PairCount: SizeUInt;
begin
  if IsMap then
    Result := ChildCount div 2
  else
    Result := 0;
end;

function TCborValue.PairKeyAt(const APairIndex: SizeUInt): TCborValue;
begin
  Result := ChildAt(APairIndex * 2);
end;

function TCborValue.PairValueAt(const APairIndex: SizeUInt): TCborValue;
begin
  Result := ChildAt(APairIndex * 2 + 1);
end;

function TCborValue.Get(const ATextKey: string): TCborValue;
begin
  Result := Get(TStringView.FromStr(ATextKey));
end;

function TCborValue.Get(const ATextKey: TStringView): TCborValue;
var
  LPairs, LI: SizeUInt;
  LKey: TCborValue;
begin
  Result := Default(TCborValue);
  if not IsMap then
    Exit;
  LPairs := PairCount;
  for LI := 0 to LPairs - 1 do
  begin
    LKey := PairKeyAt(LI);
    if LKey.IsText and LKey.AsStr.Equals(ATextKey) then
      Exit(PairValueAt(LI));
  end;
end;

function TCborValue.GetInt(const AKey: Int64): TCborValue;
var
  LPairs, LI: SizeUInt;
  LKey: TCborValue;
begin
  Result := Default(TCborValue);
  if not IsMap then
    Exit;
  LPairs := PairCount;
  for LI := 0 to LPairs - 1 do
  begin
    LKey := PairKeyAt(LI);
    if LKey.IsInt and (LKey.AsInt = AKey) then
      Exit(PairValueAt(LI));
  end;
end;

{ ===== builder ===== }

type
  TCborBuilderImpl = class(TInterfacedObject, ICborBuilder)
  private
    FBuf: TBytes;
    procedure EmitByte(const AB: Byte);
    procedure EmitHead(const AMajor, AArgument: UInt64);
    procedure AppendRaw(const AData: PByte; const ALen: SizeUInt);
  public
    constructor Create;
    procedure Uint(const AValue: UInt64);
    procedure NegInt(const AFinal: Int64);
    procedure Int(const AValue: Int64);
    procedure Bytes(const AValue: TBytes);
    procedure Text(const AValue: string);
    procedure Bool(const AValue: Boolean);
    procedure Null;
    procedure Float(const AValue: Double);
    procedure BeginArray(const AItemCount: SizeUInt);
    procedure BeginMap(const APairCount: SizeUInt);
    function ToBytes: TBytes;
  end;

function CborBuilder: ICborBuilder;
begin
  Result := TCborBuilderImpl.Create;
end;

constructor TCborBuilderImpl.Create;
begin
  inherited Create;
  FBuf := nil;
end;

procedure TCborBuilderImpl.EmitByte(const AB: Byte);
var
  LN: SizeUInt;
begin
  LN := Length(FBuf);
  SetLength(FBuf, LN + 1);
  FBuf[LN] := AB;
end;

procedure TCborBuilderImpl.AppendRaw(const AData: PByte; const ALen: SizeUInt);
var
  LN: SizeUInt;
begin
  if ALen = 0 then
    Exit;
  LN := Length(FBuf);
  SetLength(FBuf, LN + ALen);
  Move(AData^, FBuf[LN], ALen);
end;

{ 参数取最小字节序：arg < 24 内联；否则 1/2/4/8 字节大端（确定性输出）。 }
procedure TCborBuilderImpl.EmitHead(const AMajor, AArgument: UInt64);
var
  LAi, LN, I: Byte;
  LShift: UInt64;
begin
  if AArgument < 24 then
  begin
    EmitByte(Byte((AMajor shl 5) or AArgument));
    Exit;
  end;
  if AArgument <= $FF then
    LAi := 24
  else if AArgument <= $FFFF then
    LAi := 25
  else if AArgument <= $FFFFFFFF then
    LAi := 26
  else
    LAi := 27;
  EmitByte(Byte((AMajor shl 5) or LAi));
  LN := Byte(1) shl (LAi - 24);
  LShift := (UInt64(LN) - 1) * 8;
  for I := 1 to LN do
  begin
    EmitByte(Byte((AArgument shr LShift) and $FF));
    LShift := LShift - 8;
  end;
end;

procedure TCborBuilderImpl.Uint(const AValue: UInt64);
begin
  EmitHead(0, AValue);
end;

procedure TCborBuilderImpl.NegInt(const AFinal: Int64);
begin
  if AFinal >= 0 then
    raise EArgumentError.Create('cbor NegInt: final value must be negative');
  EmitHead(1, UInt64(-1 - AFinal));
end;

procedure TCborBuilderImpl.Int(const AValue: Int64);
begin
  if AValue < 0 then
    NegInt(AValue)
  else
    Uint(UInt64(AValue));
end;

procedure TCborBuilderImpl.Bytes(const AValue: TBytes);
begin
  if Length(AValue) = 0 then
    EmitHead(2, 0)
  else
  begin
    EmitHead(2, UInt64(Length(AValue)));
    AppendRaw(@AValue[0], SizeUInt(Length(AValue)));
  end;
end;

procedure TCborBuilderImpl.Text(const AValue: string);
begin
  EmitHead(3, UInt64(Length(AValue)));
  if Length(AValue) > 0 then
    AppendRaw(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
end;

procedure TCborBuilderImpl.Bool(const AValue: Boolean);
begin
  if AValue then
    EmitByte($F5)
  else
    EmitByte($F4);
end;

procedure TCborBuilderImpl.Null;
begin
  EmitByte($F6);
end;

procedure TCborBuilderImpl.Float(const AValue: Double);
var
  LBits: UInt64;
begin
  LBits := 0;
  Move(AValue, LBits, SizeOf(LBits));
  EmitByte($FB);                                                   { major 7, ai 27 }
  EmitByte(Byte((LBits shr 56) and $FF));
  EmitByte(Byte((LBits shr 48) and $FF));
  EmitByte(Byte((LBits shr 40) and $FF));
  EmitByte(Byte((LBits shr 32) and $FF));
  EmitByte(Byte((LBits shr 24) and $FF));
  EmitByte(Byte((LBits shr 16) and $FF));
  EmitByte(Byte((LBits shr 8) and $FF));
  EmitByte(Byte(LBits and $FF));
end;

procedure TCborBuilderImpl.BeginArray(const AItemCount: SizeUInt);
begin
  EmitHead(4, AItemCount);
end;

procedure TCborBuilderImpl.BeginMap(const APairCount: SizeUInt);
begin
  EmitHead(5, APairCount);
end;

function TCborBuilderImpl.ToBytes: TBytes;
begin
  Result := Copy(FBuf, 0, Length(FBuf));
end;

end.
