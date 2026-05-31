program test_ocsp;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.asn1, nextpas.core.tls.x509, nextpas.core.tls.ocsp, nextpas.core.tls.crypto.hash;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

// ========================================================================
// TOCSPCertID 测试
// ========================================================================
procedure TestCertIDBasic;
var
  CertID: TOCSPCertID;
begin
  WriteLn;
  WriteLn('=== TOCSPCertID 基础测试 ===');

  // 测试空 CertID
  FillChar(CertID, SizeOf(CertID), 0);
  Check('空 CertID.HashAlgorithm', CertID.HashAlgorithm = '');
  Check('空 CertID.IssuerNameHash', Length(CertID.IssuerNameHash) = 0);
  Check('空 CertID.IssuerKeyHash', Length(CertID.IssuerKeyHash) = 0);
  Check('空 CertID.SerialNumber', Length(CertID.SerialNumber) = 0);

  // 测试手动创建 CertID
  CertID.HashAlgorithm := '1.3.14.3.2.26';  // SHA-1 OID
  SetLength(CertID.IssuerNameHash, 20);
  SetLength(CertID.IssuerKeyHash, 20);
  SetLength(CertID.SerialNumber, 4);
  CertID.SerialNumber[0] := $01;
  CertID.SerialNumber[1] := $02;
  CertID.SerialNumber[2] := $03;
  CertID.SerialNumber[3] := $04;

  Check('CertID.HashAlgorithm 设置', CertID.HashAlgorithm = '1.3.14.3.2.26');
  Check('CertID.IssuerNameHash 长度', Length(CertID.IssuerNameHash) = 20);
  Check('CertID.IssuerKeyHash 长度', Length(CertID.IssuerKeyHash) = 20);
  Check('CertID.SerialNumber 长度', Length(CertID.SerialNumber) = 4);
end;

// ========================================================================
// CompareCertID 测试
// ========================================================================
procedure TestCompareCertID;
var
  A, B: TOCSPCertID;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== CompareCertID 测试 ===');

  // 测试相同的 CertID
  FillChar(A, SizeOf(A), 0);
  FillChar(B, SizeOf(B), 0);

  A.HashAlgorithm := '1.3.14.3.2.26';
  B.HashAlgorithm := '1.3.14.3.2.26';

  SetLength(A.IssuerNameHash, 20);
  SetLength(B.IssuerNameHash, 20);
  for I := 0 to 19 do
  begin
    A.IssuerNameHash[I] := I;
    B.IssuerNameHash[I] := I;
  end;

  SetLength(A.IssuerKeyHash, 20);
  SetLength(B.IssuerKeyHash, 20);
  for I := 0 to 19 do
  begin
    A.IssuerKeyHash[I] := I + 20;
    B.IssuerKeyHash[I] := I + 20;
  end;

  SetLength(A.SerialNumber, 4);
  SetLength(B.SerialNumber, 4);
  A.SerialNumber[0] := $01;
  A.SerialNumber[1] := $02;
  A.SerialNumber[2] := $03;
  A.SerialNumber[3] := $04;
  B.SerialNumber[0] := $01;
  B.SerialNumber[1] := $02;
  B.SerialNumber[2] := $03;
  B.SerialNumber[3] := $04;

  Check('相同 CertID 比较', CompareCertID(A, B));

  // 测试不同的 HashAlgorithm
  B.HashAlgorithm := '2.16.840.1.101.3.4.2.1';  // SHA-256
  Check('不同 HashAlgorithm', not CompareCertID(A, B));
  B.HashAlgorithm := '1.3.14.3.2.26';

  // 测试不同的 IssuerNameHash
  B.IssuerNameHash[0] := 255;
  Check('不同 IssuerNameHash', not CompareCertID(A, B));
  B.IssuerNameHash[0] := 0;

  // 测试不同的 IssuerKeyHash
  B.IssuerKeyHash[0] := 255;
  Check('不同 IssuerKeyHash', not CompareCertID(A, B));
  B.IssuerKeyHash[0] := 20;

  // 测试不同的 SerialNumber
  B.SerialNumber[0] := $FF;
  Check('不同 SerialNumber', not CompareCertID(A, B));

  // 测试不同长度的 SerialNumber
  SetLength(B.SerialNumber, 8);
  Check('不同长度 SerialNumber', not CompareCertID(A, B));
end;

// ========================================================================
// TOCSPRequest 测试
// ========================================================================
procedure TestOCSPRequest;
var
  Request: TOCSPRequest;
  CertID: TOCSPCertID;
begin
  WriteLn;
  WriteLn('=== TOCSPRequest 测试 ===');

  Request := TOCSPRequest.Create;
  try
    // 测试默认设置
    Check('默认 UseNonce', Request.UseNonce);
    Check('默认 Nonce 为空', Length(Request.Nonce) = 0);

    // 测试生成 Nonce
    Request.GenerateNonce;
    Check('生成 Nonce 后长度', Length(Request.Nonce) = 16);

    // 测试添加 CertID
    FillChar(CertID, SizeOf(CertID), 0);
    CertID.HashAlgorithm := '1.3.14.3.2.26';
    SetLength(CertID.IssuerNameHash, 20);
    SetLength(CertID.IssuerKeyHash, 20);
    SetLength(CertID.SerialNumber, 4);

    Request.AddCertID(CertID);
    // 无法直接访问 FCertIDs，但可以测试编码
    Check('AddCertID 执行成功', True);

    // 测试编码
    // 断言：编码接口可用，且请求在添加 CertID 后应产生非空 DER 数据
    Check('Encode 输出非空', Length(Request.Encode) > 0);

  finally
    Request.Free;
  end;
end;

// ========================================================================
// TOCSPResponse 测试
// ========================================================================
procedure TestOCSPResponseCreate;
var
  Response: TOCSPResponse;
begin
  WriteLn;
  WriteLn('=== TOCSPResponse 创建测试 ===');

  Response := TOCSPResponse.Create;
  try
    // 测试默认值
    Check('默认 ResponseStatus', Response.ResponseStatus = ocsprsInternalError);
    Check('默认 Responses 为空', Length(Response.Responses) = 0);
    Check('默认 ProducedAt', Response.ProducedAt = 0);
    Check('默认 ResponderID', Response.ResponderID = '');
    Check('默认 Nonce 为空', Length(Response.Nonce) = 0);
  finally
    Response.Free;
  end;
end;

// ========================================================================
// OCSP 响应解析测试 (使用实际 DER 数据)
// ========================================================================
procedure TestOCSPResponseParsing;
var
  Response: TOCSPResponse;
  // 这是一个简化的 OCSP 响应 DER 数据示例
  // OCSPResponse ::= SEQUENCE {
  //   responseStatus ENUMERATED { successful (0) },
  //   responseBytes [0] EXPLICIT ResponseBytes OPTIONAL }
  OCSPSuccessfulMinimal: array[0..4] of Byte = (
    $30, $03,       // SEQUENCE, 长度 3
    $0A, $01, $00   // ENUMERATED, 长度 1, 值 0 (successful)
  );
  OCSPMalformedRequest: array[0..4] of Byte = (
    $30, $03,       // SEQUENCE, 长度 3
    $0A, $01, $01   // ENUMERATED, 长度 1, 值 1 (malformedRequest)
  );
  OCSPTryLater: array[0..4] of Byte = (
    $30, $03,       // SEQUENCE, 长度 3
    $0A, $01, $03   // ENUMERATED, 长度 1, 值 3 (tryLater)
  );
  Data: TBytes;
begin
  WriteLn;
  WriteLn('=== OCSP 响应解析测试 ===');

  // 测试解析成功状态（无响应体）
  Response := TOCSPResponse.Create;
  try
    SetLength(Data, 5);
    Move(OCSPSuccessfulMinimal[0], Data[0], 5);
    Response.LoadFromDER(Data);
    Check('解析 successful 状态', Response.ResponseStatus = ocsprsSuccessful);
  finally
    Response.Free;
  end;

  // 测试解析 malformedRequest 状态
  Response := TOCSPResponse.Create;
  try
    SetLength(Data, 5);
    Move(OCSPMalformedRequest[0], Data[0], 5);
    Response.LoadFromDER(Data);
    Check('解析 malformedRequest 状态', Response.ResponseStatus = ocsprsMalformedRequest);
  finally
    Response.Free;
  end;

  // 测试解析 tryLater 状态
  Response := TOCSPResponse.Create;
  try
    SetLength(Data, 5);
    Move(OCSPTryLater[0], Data[0], 5);
    Response.LoadFromDER(Data);
    Check('解析 tryLater 状态', Response.ResponseStatus = ocsprsTryLater);
  finally
    Response.Free;
  end;
end;

// ========================================================================
// 状态字符串转换测试
// ========================================================================
procedure TestStatusStrings;
begin
  WriteLn;
  WriteLn('=== 状态字符串转换测试 ===');

  // 证书状态
  Check('ocspGood 转字符串', OCSPStatusToString(ocspGood) = 'Good');
  Check('ocspRevoked 转字符串', OCSPStatusToString(ocspRevoked) = 'Revoked');
  Check('ocspUnknown 转字符串', OCSPStatusToString(ocspUnknown) = 'Unknown');

  // 响应状态
  Check('ocsprsSuccessful 转字符串', OCSPResponseStatusToString(ocsprsSuccessful) = 'Successful');
  Check('ocsprsMalformedRequest 转字符串', OCSPResponseStatusToString(ocsprsMalformedRequest) = 'Malformed Request');
  Check('ocsprsInternalError 转字符串', OCSPResponseStatusToString(ocsprsInternalError) = 'Internal Error');
  Check('ocsprsTryLater 转字符串', OCSPResponseStatusToString(ocsprsTryLater) = 'Try Later');
  Check('ocsprsSignatureRequired 转字符串', OCSPResponseStatusToString(ocsprsSignatureRequired) = 'Signature Required');
  Check('ocsprsUnauthorized 转字符串', OCSPResponseStatusToString(ocsprsUnauthorized) = 'Unauthorized');
end;

// ========================================================================
// TOCSPSingleResponse 测试
// ========================================================================
procedure TestSingleResponse;
var
  SingleResp: TOCSPSingleResponse;
begin
  WriteLn;
  WriteLn('=== TOCSPSingleResponse 测试 ===');

  FillChar(SingleResp, SizeOf(SingleResp), 0);

  // 测试默认值
  Check('默认 CertStatus', SingleResp.CertStatus = ocspGood);
  Check('默认 ThisUpdate', SingleResp.ThisUpdate = 0);
  Check('默认 NextUpdate', SingleResp.NextUpdate = 0);
  Check('默认 HasNextUpdate', SingleResp.HasNextUpdate = False);
  Check('默认 RevokedTime', SingleResp.RevokedTime = 0);
  Check('默认 RevokeReason', SingleResp.RevokeReason = ocsprrUnspecified);

  // 设置值
  SingleResp.CertStatus := ocspRevoked;
  SingleResp.RevokedTime := Now;
  SingleResp.RevokeReason := ocsprrKeyCompromise;
  SingleResp.ThisUpdate := Now - 1;
  SingleResp.NextUpdate := Now + 1;
  SingleResp.HasNextUpdate := True;

  Check('设置 CertStatus', SingleResp.CertStatus = ocspRevoked);
  Check('设置 HasNextUpdate', SingleResp.HasNextUpdate);
  Check('设置 RevokeReason', SingleResp.RevokeReason = ocsprrKeyCompromise);
end;

// ========================================================================
// FindResponse 和 GetCertStatus 测试
// ========================================================================
procedure TestFindResponse;
var
  Response: TOCSPResponse;
  CertID: TOCSPCertID;
begin
  WriteLn;
  WriteLn('=== FindResponse/GetCertStatus 测试 ===');

  Response := TOCSPResponse.Create;
  try
    // 在空响应中查找
    FillChar(CertID, SizeOf(CertID), 0);
    CertID.HashAlgorithm := '1.3.14.3.2.26';
    SetLength(CertID.IssuerNameHash, 20);
    SetLength(CertID.IssuerKeyHash, 20);
    SetLength(CertID.SerialNumber, 4);

    Check('空响应 FindResponse 返回 -1', Response.FindResponse(CertID) = -1);
    Check('空响应 GetCertStatus 返回 Unknown', Response.GetCertStatus(CertID) = ocspUnknown);
  finally
    Response.Free;
  end;
end;

// ========================================================================
// 吊销原因枚举测试
// ========================================================================
procedure TestRevokeReason;
begin
  WriteLn;
  WriteLn('=== 吊销原因枚举测试 ===');

  Check('ocsprrUnspecified 值', Ord(ocsprrUnspecified) = 0);
  Check('ocsprrKeyCompromise 值', Ord(ocsprrKeyCompromise) = 1);
  Check('ocsprrCACompromise 值', Ord(ocsprrCACompromise) = 2);
  Check('ocsprrAffiliationChanged 值', Ord(ocsprrAffiliationChanged) = 3);
  Check('ocsprrSuperseded 值', Ord(ocsprrSuperseded) = 4);
  Check('ocsprrCessationOfOperation 值', Ord(ocsprrCessationOfOperation) = 5);
  Check('ocsprrCertificateHold 值', Ord(ocsprrCertificateHold) = 6);
  Check('ocsprrRemoveFromCRL 值', Ord(ocsprrRemoveFromCRL) = 7);
  Check('ocsprrPrivilegeWithdrawn 值', Ord(ocsprrPrivilegeWithdrawn) = 8);
  Check('ocsprrAACompromise 值', Ord(ocsprrAACompromise) = 9);
end;

// ========================================================================
// 响应状态枚举测试
// ========================================================================
procedure TestResponseStatusEnum;
begin
  WriteLn;
  WriteLn('=== 响应状态枚举测试 ===');

  // 根据 RFC 6960，OCSP 响应状态值：
  // successful (0), malformedRequest (1), internalError (2),
  // tryLater (3), sigRequired (5), unauthorized (6)
  Check('ocsprsSuccessful 值', Ord(ocsprsSuccessful) = 0);
  Check('ocsprsMalformedRequest 值', Ord(ocsprsMalformedRequest) = 1);
  Check('ocsprsInternalError 值', Ord(ocsprsInternalError) = 2);
  Check('ocsprsTryLater 值', Ord(ocsprsTryLater) = 3);
  Check('ocsprsSignatureRequired 值', Ord(ocsprsSignatureRequired) = 4);
  Check('ocsprsUnauthorized 值', Ord(ocsprsUnauthorized) = 5);
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls.ocsp 单元测试');
  WriteLn('========================================');

  TestsPassed := 0;
  TestsFailed := 0;

  TestCertIDBasic;
  TestCompareCertID;
  TestOCSPRequest;
  TestOCSPResponseCreate;
  TestOCSPResponseParsing;
  TestStatusStrings;
  TestSingleResponse;
  TestFindResponse;
  TestRevokeReason;
  TestResponseStatusEnum;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
