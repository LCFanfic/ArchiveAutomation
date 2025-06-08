function Meta(meta)
  if meta.title and #meta.title == 1 then
    meta.title = pandoc.Inlines(meta.title[1].content)
  elseif  meta.title and #meta.title > 1 then
    print("Title with more than one paragraph detected! This will render incorrectly.")
  end

  if meta.summary and #meta.summary == 1 then
    meta.summary = pandoc.Inlines(meta.summary[1].content)
  elseif  meta.summary and #meta.summary > 1 then
    print("Summary with more than one paragraph detected! This will render incorrectly.")
  end

  if meta.authors_formatted and #meta.authors_formatted == 1 and meta.authors_formatted[1].text then
    local authors_formatted = meta.authors_formatted[1].text
    authors_formatted = string.gsub(authors_formatted, "(https?://www%.lcfanfic%.com", "")
    authors_formatted = string.gsub(authors_formatted, "(https?://lcfanfic%.com", "")
    meta.authors_formatted = pandoc.Inlines(pandoc.read(authors_formatted, "markdown").blocks[1].content)
  end

  return meta
end

function Header(el)
  -- Level 1: page title
  -- Level 2: story title on page
  el.level = el.level + 2
  return el
end