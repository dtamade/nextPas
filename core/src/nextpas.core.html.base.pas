unit nextpas.core.html.base;

{$I nextpas.core.settings.inc}

interface

type
  { HTML→文本提取选项（record 值语义，按值传递，修改不影响默认值）。 }
  THtmlExtractOptions = record
    { 保留 <a href=...> 的 URL：输出为 "文本 (url)"；默认去掉 URL。 }
    KeepLinks: Boolean;
    { h1-h6 按块级元素处理（内容前后换行）；默认视为行内文本折叠进正文。 }
    KeepHeadings: Boolean;
    { 折叠连续空白为单个空格（&nbsp; 亦折叠）；默认开启。 }
    CollapseWhitespace: Boolean;
  end;

const
  DefaultHtmlExtractOptions: THtmlExtractOptions = (
    KeepLinks: False;
    KeepHeadings: False;
    CollapseWhitespace: True
  );

implementation

end.