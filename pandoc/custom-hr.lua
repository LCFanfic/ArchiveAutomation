local horizontalRuleDocx = [[<w:p>
  <w:pPr>
    <w:pStyle w:val="HorizontalRule"/>
  </w:pPr>
  <w:r>
    <w:t>✽ ✽ ✽</w:t>
  </w:r>
</w:p>]]

local horizontalRuleOdt = [[<text:p text:style-name="Horizontal Rule">✽ ✽ ✽</text:p>]]

local horizontalRuleHtml = [[<div role="separator" class="horizontalrule">✽ ✽ ✽</div>]]

function HorizontalRule ()
  if FORMAT == 'docx' then
    return pandoc.RawBlock('openxml', horizontalRuleDocx)
  elseif FORMAT == 'odt' then
    return pandoc.RawBlock('opendocument', horizontalRuleOdt)
  elseif FORMAT == 'epub' then
    return pandoc.RawBlock('html', horizontalRuleHtml)
  elseif FORMAT == 'html' then
    return pandoc.RawBlock('html', horizontalRuleHtml)
  elseif FORMAT == 'txt' then
    return pandoc.RawBlock('txt', "***")
  else
    return pandoc.Para({pandoc.Str("***")})
  end
end