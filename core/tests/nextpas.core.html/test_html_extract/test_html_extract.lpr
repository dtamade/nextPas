program test_html_extract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.html,
  nextpas.core.html.base;

var
  T: TTestSuite;

procedure ExpectHtmlTooLong;
var
  S: string;
begin
  S := StringOfChar('a', MaxHtmlInputLength + 1);
  HtmlTextOf(S);
end;

{ 正常：简单文本与纯文本 }

procedure TestSimpleText;
begin
  CheckEqual('hello world', HtmlTextOf('hello world'));
  CheckEqual('hello bold world', HtmlTextOf('hello <b>bold</b> world'));
  CheckEqual('hello b world', HtmlTextOf('hello <b attr="x">b</b> world'));
end;

procedure TestEmptyAndPlain;
begin
  CheckEqual('', HtmlTextOf(''));
  CheckEqual('plain', HtmlTextOf('plain'));
  CheckEqual('passthrough 123!?', HtmlTextOf('passthrough 123!?'));
  Check(Length(HtmlTextOf('中文原文')) = 12, 'utf-8 passthrough');
  CheckEqual('x', HtmlTextOf(#$EF#$BB#$BF + 'x'), 'utf-8 BOM stripped');
end;

{ 正常：嵌套标签 }

procedure TestNestedTags;
begin
  CheckEqual('one two', HtmlTextOf('<div><p>one <span>two</span></p></div>'));
  CheckEqual('a'#10'b'#10'c', HtmlTextOf('<div><div>a <div>b</div> c</div></div>'),
    'nested blocks break lines');
  CheckEqual('xy', HtmlTextOf('<p><span>x</span><span>y</span></p>'));
  CheckEqual('nested', HtmlTextOf('<a href="u"><b><i>nested</i></b></a>'));
end;

{ 正常：script/style/noscript/head 剔除（大小写不敏感） }

procedure TestHiddenContentRemoved;
begin
  CheckEqual('body', HtmlTextOf('<script>if (a < b) { x(); }</script><p>body</p>'));
  CheckEqual('body', HtmlTextOf('<SCRIPT>alert(1)</SCRIPT><p>body</p>'));
  CheckEqual('body', HtmlTextOf('<Style>.a{color:red}</Style><p>body</p>'));
  CheckEqual('body', HtmlTextOf('<NoScRiPt><div>ns</div></NoScRiPt><p>body</p>'));
  CheckEqual('B',
    HtmlTextOf('<HEAD><title>T</title><meta charset="utf-8"></HEAD><BODY>B</BODY>'));
  CheckEqual('a b', HtmlTextOf('a<script>var x=1;</script> b'));
  { 截断的 script 吞掉剩余输入 }
  CheckEqual('a', HtmlTextOf('a<script>var x = 1;'));
  { 元素名边界：</scriptx 不算闭合 }
  CheckEqual('', HtmlTextOf('<script>x</scriptx>y'));
end;

{ 正常：注释与 DOCTYPE/CDATA }

procedure TestDeclarations;
begin
  CheckEqual('text', HtmlTextOf('<!-- comment -->text'));
  CheckEqual('ab', HtmlTextOf('a<!-- c -->b'));
  CheckEqual('x', HtmlTextOf('<!DOCTYPE html><html><body>x</body></html>'));
  CheckEqual('x', HtmlTextOf('<![CDATA[<b>raw</b>]]>x'));
  CheckEqual('ac', HtmlTextOf('a<![CDATA[<b>raw</b>]]>c'));
  CheckEqual('x', HtmlTextOf('<?xml version="1.0"?>x'));
  { 截断注释吞掉剩余输入 }
  CheckEqual('', HtmlTextOf('<!-- unterminated'));
end;

{ 实体与数字实体解码 }

procedure TestEntityDecode;
begin
  CheckEqual('&<>"' + '''', HtmlDecodeEntities('&amp;&lt;&gt;&quot;&apos;'));
  CheckEqual(#$C2#$A9, HtmlDecodeEntities('&copy;'));
  CheckEqual(#$C2#$A9 + ' ' + #$C2#$A9 + ' ' + #$C2#$A9,
    HtmlDecodeEntities('&copy; &#169; &#xA9;'));
  CheckEqual('ABC', HtmlDecodeEntities('&#65;&#x42;&#X43;'));
  CheckEqual(#$C3#$AB, HtmlDecodeEntities('&euml;'));
  CheckEqual(#$E2#$80#$A6, HtmlDecodeEntities('&hellip;'));
  CheckEqual(#$E2#$82#$AC, HtmlDecodeEntities('&euro;'));
  CheckEqual(#$CE#$B1 + #$CE#$A9, HtmlDecodeEntities('&alpha;&Omega;'));
  CheckEqual(#$C2#$A0, HtmlDecodeEntities('&nbsp;'));
end;

procedure TestEntityDecodeMalformed;
begin
  { 未转义 &、未知/畸形实体原样保留 }
  CheckEqual('a&b', HtmlDecodeEntities('a&b'));
  CheckEqual('AT&T', HtmlDecodeEntities('AT&T'));
  CheckEqual('&unknown;', HtmlDecodeEntities('&unknown;'));
  CheckEqual('&AMP;', HtmlDecodeEntities('&AMP;'), 'case-sensitive names');
  CheckEqual('&#0;', HtmlDecodeEntities('&#0;'), 'null code point passthrough');
  CheckEqual('&#xD800;', HtmlDecodeEntities('&#xD800;'), 'surrogate passthrough');
  CheckEqual('&#x110000;', HtmlDecodeEntities('&#x110000;'), 'out-of-range passthrough');
  CheckEqual('&#99999999999;', HtmlDecodeEntities('&#99999999999;'),
    'overflow passthrough');
  CheckEqual('&#x;', HtmlDecodeEntities('&#x;'), 'no digits passthrough');
  { 无分号宽容 / 不误吞 }
  CheckEqual('&', HtmlDecodeEntities('&amp'));
  CheckEqual('A', HtmlDecodeEntities('&#65'));
  CheckEqual('&ampx', HtmlDecodeEntities('&ampx'), 'no alnum-swallow');
  { 单遍解码，不二次解析 }
  CheckEqual('<script>', HtmlDecodeEntities('&lt;script&gt;'));
  CheckEqual('&amp;', HtmlDecodeEntities('&amp;amp;'));
  CheckEqual('', HtmlDecodeEntities(''));
  CheckEqual('no entities here', HtmlDecodeEntities('no entities here'));
end;

procedure TestEntityInExtraction;
begin
  CheckEqual('a & b', HtmlTextOf('<p>a &amp; b</p>'));
  CheckEqual('a & b / c', HtmlTextOf('<p>a &amp; b &#x2F; c</p>'));
  CheckEqual('a b', HtmlTextOf('<p>a&nbsp;b</p>'), 'nbsp folds to space');
  CheckEqual('a b', HtmlTextOf('<p>a&nbsp; &nbsp;b</p>'), 'nbsp+space single fold');
  CheckEqual('a &', HtmlTextOf('a &'));
  CheckEqual('x&y', HtmlTextOf('x&y'));
  CheckEqual('AT&T', HtmlTextOf('AT&T'));
end;

{ 块级换行与空白折叠 }

procedure TestBlockBreaks;
begin
  CheckEqual('a'#10'b', HtmlTextOf('<div>a</div><div>b</div>'));
  CheckEqual('a'#10'b', HtmlTextOf('<p>a</p><p>b</p>'));
  CheckEqual('x'#10'y', HtmlTextOf('<ul><li>x</li><li>y</li></ul>'));
  CheckEqual('a'#10'b', HtmlTextOf('a<br>b'));
  CheckEqual('a'#10'b', HtmlTextOf('a<br/>b'));
  CheckEqual('m'#10'n', HtmlTextOf('<table><tr><td>m</td><td>n</td></tr></table>'));
  { 连续块边界只产生一个换行 }
  CheckEqual('a'#10'b', HtmlTextOf('<p>a</p>  <p>b</p>'));
  CheckEqual('a'#10'b', HtmlTextOf('<p>a</p>'#10#10#10'<p>b</p>'));
  CheckEqual('a'#10'b', HtmlTextOf('<p>a</p><div></div><p>b</p>'));
  CheckEqual('a'#10'b'#10'c', HtmlTextOf('<p>a</p><p>b</p><p>c</p>'));
end;

procedure TestWhitespaceCollapse;
var
  LNoCollapse: THtmlExtractOptions;
begin
  CheckEqual('a b', HtmlTextOf('<p>a    b</p>'));
  CheckEqual('a b', HtmlTextOf('a '#9' '#10' b'));
  CheckEqual('a b', HtmlTextOf('a    b'));
  { 行首空白丢弃 }
  CheckEqual('x', HtmlTextOf('  <p>x</p>  '));
  { 块边界前的空白由换行取代 }
  CheckEqual('a'#10'b', HtmlTextOf('a   <p>b</p>'));
  { 保留空白选项 }
  LNoCollapse := DefaultHtmlExtractOptions;
  LNoCollapse.CollapseWhitespace := False;
  CheckEqual('a   b', HtmlTextOf('a   b', LNoCollapse));
  CheckEqual('a   b', HtmlTextOf('<p>a   b</p>', LNoCollapse));
  CheckEqual('a'#9'b', HtmlTextOf('a'#9'b', LNoCollapse));
  { 块边界换行与空白选项无关 }
  CheckEqual('a'#10'b', HtmlTextOf('<p>a</p><p>b</p>', LNoCollapse));
end;

{ 畸形输入容错 }

procedure TestMalformedInput;
begin
  CheckEqual('text', HtmlTextOf('<p>text'), 'unclosed open tag');
  CheckEqual('text', HtmlTextOf('text</p>'), 'stray close tag');
  CheckEqual('x', HtmlTextOf('<b><i>x</b></i>'), 'unbalanced nesting');
  CheckEqual('a < b > c', HtmlTextOf('a < b > c'), 'literal angle operators');
  CheckEqual('2 < 3', HtmlTextOf('2 < 3'));
  CheckEqual('', HtmlTextOf('<div'), 'truncated tag');
  CheckEqual('a', HtmlTextOf('a<x'), 'lt before alpha treated as tag until EOF');
  CheckEqual('t', HtmlTextOf('<a href=foo>t</a>'), 'unquoted attribute');
  CheckEqual('x', HtmlTextOf('<a title="a>b">x</a>'), 'gt inside quoted attribute');
  CheckEqual('t', HtmlTextOf('<a href="x">t</a'), 'unterminated close tag');
  CheckEqual('<3', HtmlTextOf('<3'), 'lt digit');
  CheckEqual('ok', HtmlTextOf('<!--x--><![CDATA[y]]>ok'));
end;

{ KeepLinks 选项 }

procedure TestKeepLinks;
var
  LLinks: THtmlExtractOptions;
begin
  LLinks := DefaultHtmlExtractOptions;
  LLinks.KeepLinks := True;
  CheckEqual('click', HtmlTextOf('<a href="https://x.com">click</a>'),
    'default drops url');
  CheckEqual('click (https://x.com)',
    HtmlTextOf('<a href="https://x.com">click</a>', LLinks), 'keep url');
  CheckEqual('click', HtmlTextOf('<a>click</a>', LLinks), 'no href -> no suffix');
  CheckEqual('x (/q?a=1&b=2)',
    HtmlTextOf('<a href="/q?a=1&amp;b=2">x</a>', LLinks), 'entity decoded href');
  CheckEqual('a (u) b (v)',
    HtmlTextOf('<a href="u">a</a> <a href="v">b</a>', LLinks), 'multiple anchors');
  CheckEqual('t', HtmlTextOf('<a href="u"> </a>t', LLinks), 'ws-only anchor');
end;

{ KeepHeadings 选项 }

procedure TestKeepHeadings;
var
  LHeadings: THtmlExtractOptions;
begin
  CheckEqual('TitleBody', HtmlTextOf('<h1>Title</h1>Body'),
    'default heading inline folded');
  LHeadings := DefaultHtmlExtractOptions;
  LHeadings.KeepHeadings := True;
  CheckEqual('Title'#10'Body',
    HtmlTextOf('<h1>Title</h1>Body', LHeadings), 'heading block breaks');
  CheckEqual('AB', HtmlTextOf('<h2>A</h2><h3>B</h3>'), 'heading inline default');
  CheckEqual('A'#10'B', HtmlTextOf('<h2>A</h2><h3>B</h3>', LHeadings));
  { 内容永远保留：选项只改换行结构 }
  CheckEqual('Title'#10'Body',
    HtmlTextOf('<h1>Title</h1><p>Body</p>', LHeadings));
end;

{ img alt 文本 }

procedure TestImgAlt;
begin
  CheckEqual('A pic', HtmlTextOf('<img src="a.png" alt="A pic">'));
  CheckEqual('', HtmlTextOf('<img src="a.png">'));
  CheckEqual('a & b', HtmlTextOf('<img alt="a &amp; b">'));
  CheckEqual('xy', HtmlTextOf('x<img alt="y">'));
end;

{ 超长输入边界 }

procedure TestLongInput;
var
  I, P: Integer;
  LHtml, LExpected, LOut: string;
begin
  { 1MiB 纯文本原样通过 }
  LHtml := StringOfChar('a', 1024 * 1024);
  LOut := HtmlTextOf(LHtml);
  CheckEqual(Length(LHtml), Length(LOut), 'long plain passthrough length');
  Check(LOut = LHtml, 'long plain passthrough content');
  { 3 万个块级标签：只产生块间换行，不崩溃 }
  SetLength(LHtml, 30000 * 9);
  for I := 0 to 29999 do
    Move('<p>ab</p>'[1], LHtml[I * 9 + 1], 9);
  SetLength(LExpected, 30000 * 2 + 29999);
  P := 1;
  for I := 0 to 29999 do
  begin
    Move('ab'[1], LExpected[P], 2);
    Inc(P, 2);
    if I < 29999 then
    begin
      LExpected[P] := #10;
      Inc(P);
    end;
  end;
  LOut := HtmlTextOf(LHtml);
  CheckEqual(Length(LExpected), Length(LOut), 'long tags length');
  Check(LOut = LExpected, 'long tags content');
end;

{ 输入长度上限（错误路径） }

procedure TestInputLimit;
var
  LText, LAtLimit: string;
begin
  LAtLimit := StringOfChar('x', MaxHtmlInputLength);
  CheckEqual(LAtLimit, HtmlTextOf(LAtLimit), 'at-limit input accepted');
  CheckRaises(EArgumentError, @ExpectHtmlTooLong, 'exceeds MaxHtmlInputLength');
  Check(not TryHtmlTextOf(StringOfChar('x', MaxHtmlInputLength + 1), LText),
    'Try variant returns False beyond limit');
  CheckEqual('', LText, 'failed Try leaves empty out');
end;

{ TryHtmlTextOf 对偶 }

procedure TestTryHtmlTextOf;
var
  LText: string;
begin
  Check(TryHtmlTextOf('<p>hi</p>', LText), 'Try success');
  CheckEqual('hi', LText);
  Check(TryHtmlTextOf('', LText), 'Try empty input');
  CheckEqual('', LText);
  Check(TryHtmlTextOf('<b>caf&#xE9;</b>', LText), 'Try entity');
  CheckEqual('caf'#$C3#$A9, LText);
end;

begin
  T := TTestSuite.Create('nextpas.core.html');

  T.Test('simple text', @TestSimpleText);
  T.Test('empty and plain', @TestEmptyAndPlain);
  T.Test('nested tags', @TestNestedTags);
  T.Test('hidden content removed', @TestHiddenContentRemoved);
  T.Test('declarations', @TestDeclarations);
  T.Test('entity decode', @TestEntityDecode);
  T.Test('entity decode malformed', @TestEntityDecodeMalformed);
  T.Test('entities in extraction', @TestEntityInExtraction);
  T.Test('block breaks', @TestBlockBreaks);
  T.Test('whitespace collapse', @TestWhitespaceCollapse);
  T.Test('malformed input', @TestMalformedInput);
  T.Test('KeepLinks option', @TestKeepLinks);
  T.Test('KeepHeadings option', @TestKeepHeadings);
  T.Test('img alt', @TestImgAlt);
  T.Test('long input', @TestLongInput);
  T.Test('input limit', @TestInputLimit);
  T.Test('TryHtmlTextOf', @TestTryHtmlTextOf);

  if not T.Run then
    Halt(1);
end.