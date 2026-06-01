program test_xml;
{**
 * @desc XML Facade 测试套件：覆盖 nextpas.core.xml 统一导出的
 *       XmlParse / XmlTokenize / XmlDecodeEntities / XmlEncodeText /
 *       XmlEncodeAttr 五个门面函数，确保 facade 转发正确。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.xml;

var
  T: TTestRunner;

{ === XmlParse（转发 TXmlDocument.Parse） === }

procedure TestXmlParseSimple;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<root>hello</root>');
  try
    Check(LDoc.Root <> nil, 'root not nil');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name');
    CheckEqual('hello', LDoc.Root.Text, 'root text');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlParseNested;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := XmlParse('<a attr="v"><b>inner</b></a>');
  try
    CheckEqual('a', LDoc.Root.Name.Local, 'root name');
    CheckEqual('v', LDoc.Root.GetAttr('attr'), 'root attr');
    CheckEqual(Int64(1), Int64(LDoc.Root.ChildCount), 'child count');
    LChild := LDoc.Root.FindChild('b');
    Check(LChild <> nil, 'child found');
    CheckEqual('inner', LChild.Text, 'child text');
  finally
    LDoc.Free;
  end;
end;

{ === XmlTokenize（转发 TXmlReader 流式 token） === }

procedure TestXmlTokenizeBasic;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('<root>hi</root>');
  Check(Length(LToks) >= 3, 'at least start/text/end tokens');
  CheckEqual(Int64(Ord(xtkStartElement)), Int64(Ord(LToks[0].Kind)), 'first is start element');
  CheckEqual('root', LToks[0].Name.Local, 'start element name');
end;

procedure TestXmlTokenizeEmpty;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('<br/>');
  Check(Length(LToks) >= 1, 'one token for empty element');
  CheckEqual(Int64(Ord(xtkEmptyElement)), Int64(Ord(LToks[0].Kind)), 'empty element kind');
  CheckEqual('br', LToks[0].Name.Local, 'empty element name');
end;

procedure TestXmlTokenizeText;
var
  LToks: TXmlTokenArray;
  I: Integer;
  LFound: Boolean;
begin
  LToks := XmlTokenize('<p>hello world</p>');
  LFound := False;
  for I := 0 to High(LToks) do
    if LToks[I].Kind = xtkText then
    begin
      CheckEqual('hello world', LToks[I].Value, 'text token value');
      LFound := True;
    end;
  Check(LFound, 'text token present');
end;

{ === XmlDecodeEntities === }

procedure TestXmlDecodeEntities;
begin
  CheckEqual('<a> & "b" ''c''', XmlDecodeEntities('&lt;a&gt; &amp; &quot;b&quot; &apos;c&apos;'),
    'decode named entities');
end;

procedure TestXmlDecodeNumeric;
begin
  CheckEqual('AB', XmlDecodeEntities('&#65;&#66;'), 'decode decimal numeric');
  CheckEqual('AB', XmlDecodeEntities('&#x41;&#x42;'), 'decode hex numeric');
end;

{ === XmlEncodeText / XmlEncodeAttr === }

procedure TestXmlEncodeText;
begin
  CheckEqual('a &lt;b&gt; &amp; c', XmlEncodeText('a <b> & c'), 'encode text special chars');
end;

procedure TestXmlEncodeAttr;
begin
  CheckEqual('say &quot;hi&quot; &amp; bye', XmlEncodeAttr('say "hi" & bye'),
    'encode attr quotes + amp');
end;

procedure TestEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded: string;
begin
  LOriginal := 'tags <x> & "quotes" mixed';
  LEncoded := XmlEncodeText(LOriginal);
  CheckEqual(LOriginal, XmlDecodeEntities(LEncoded), 'encode/decode round-trip');
end;

{ === 边界场景 === }

procedure TestXmlParseIgnoresDeclAndDoctype;
var
  LDoc: TXmlDocument;
begin
  { 声明与 DTD 不进入 DOM，根仍为 root }
  LDoc := XmlParse('<?xml version="1.0"?><!DOCTYPE root><root/>');
  try
    Check(LDoc.Root <> nil, 'root present despite decl/doctype');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name after decl/doctype');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlTokenizeEmptyInput;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('');
  CheckEqual(Int64(0), Int64(Length(LToks)), 'empty input yields zero tokens');
end;

procedure TestXmlTokenizePropagatesError;
var
  LRaised: Boolean;
begin
  { 非法 XML 必须抛 EXmlError，而非静默返回部分 token }
  LRaised := False;
  try
    XmlTokenize('<root><unclosed>');
  except
    on E: EXmlError do
      LRaised := True;
  end;
  Check(LRaised, 'malformed XML raises EXmlError');
end;

procedure TestXmlEncodeAttrApos;
begin
  CheckEqual('it&apos;s', XmlEncodeAttr('it''s'), 'encode single quote in attr');
end;

begin
  T := TTestRunner.Create('XML Facade');
  T.Run('XmlParseSimple', @TestXmlParseSimple);
  T.Run('XmlParseNested', @TestXmlParseNested);
  T.Run('XmlTokenizeBasic', @TestXmlTokenizeBasic);
  T.Run('XmlTokenizeEmpty', @TestXmlTokenizeEmpty);
  T.Run('XmlTokenizeText', @TestXmlTokenizeText);
  T.Run('XmlDecodeEntities', @TestXmlDecodeEntities);
  T.Run('XmlDecodeNumeric', @TestXmlDecodeNumeric);
  T.Run('XmlEncodeText', @TestXmlEncodeText);
  T.Run('XmlEncodeAttr', @TestXmlEncodeAttr);
  T.Run('EncodeDecodeRoundTrip', @TestEncodeDecodeRoundTrip);
  T.Run('XmlParseIgnoresDeclAndDoctype', @TestXmlParseIgnoresDeclAndDoctype);
  T.Run('XmlTokenizeEmptyInput', @TestXmlTokenizeEmptyInput);
  T.Run('XmlTokenizePropagatesError', @TestXmlTokenizePropagatesError);
  T.Run('XmlEncodeAttrApos', @TestXmlEncodeAttrApos);
  T.Summary;
end.
