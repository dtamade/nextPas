unit nextpas.core.js.value;
{** @desc JS 值语义 JSON 单源 — TJsValue.AsJson 与 pure.base.JsPureToJsonString 收敛至此。
     单源经 json.writer.TJsonWriter 单缝 (text.escape SIMD) + text.builder 几何 via bytes.ops,
     零拷贝 BytesCopy，热点 inline 薄转发，资源 try-finally 不丢，守 L0-L3 四件套 base←intf←value。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.intf, nextpas.core.js.base;
function JsValueAsJson(const V: TJsValue): string;
function JsValueToJsonString(const V: TJsValue): string; inline;
implementation
uses
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.bytes.ops;

function JsValueAsJson(const V: TJsValue): string;
var B: TStringBuilder; W: TJsonWriter; S: string;
begin
  // single source: json.writer TJsonWriter via text.escape SIMD, builder geometric via bytes.ops, single seam for both AsJson and pure
  case V.Kind of
    jskUndefined: Exit('undefined');
    jskNull: Exit('null');
    jskBoolean: if V.AsBool then Exit('true') else Exit('false');
    jskNumber:
      begin
        // perf: single alloc geometric via bytes.ops, zero-copy AppendInt/Float inline, not inline per red-line 2 (branch+builder)
        B.Init(32);
        try
          W.Init(B);
          if Double(V.AsInt) = V.AsDouble then W.Int(V.AsInt) else W.Float(V.AsDouble);
          Result := B.ToString;
        finally B.Done; end;
        Exit;
      end;
    jskString:
      begin
        S := V.AsString;
        // perf: single source via TJsonWriter.Str single seam, text.escape SIMD single pass, builder geometric, zero-copy straight-through (clean BytesCopy)
        B.Init(SizeUInt(Length(S)) + 2);
        try
          W.Init(B);
          W.Str(S);
          Result := B.ToString;
        finally B.Done; end;
        Exit;
      end;
    jskSymbol:
      begin
        S := V.AsString;
        // perf: single source via builder geometric via bytes.ops, zero-copy BytesCopy single source, single alloc, 堆拼接单分配消除, inline Reserve/Grow
        B.Init(SizeUInt(Length(S)) + 8);
        try
          B.AppendBytes('Symbol(', 7);
          if Length(S) > 0 then B.AppendStr(S);
          B.AppendChar(')');
          Result := B.ToString;
        finally B.Done; end;
        Exit;
      end;
    jskBigInt:
      begin
        // perf: single source via builder AppendInt/AppendChar geometric via bytes.ops, zero-copy AppendInt inline, single alloc 22 (Int64 20+1+'n'), 堆拼接消除, inline Reserve/Grow
        B.Init(22);
        try
          B.AppendInt(V.AsInt);
          B.AppendChar('n');
          Result := B.ToString;
        finally B.Done; end;
        Exit;
      end;
  else
    Result := '';
  end;
end;

function JsValueToJsonString(const V: TJsValue): string; inline;
begin
  // perf: inline thin-forward to JsValueAsJson single source, zero-branch for JSON compat kinds, single seam via json.writer
  // JSON mapping: only string/number/boolean/null are JSON, others -> 'null' per JSON spec; delegate convertible kinds to AsJson single source
  case V.Kind of
    jskString, jskNumber, jskBoolean, jskNull:
      Result := JsValueAsJson(V);
  else
    Result := 'null';
  end;
end;

end.
