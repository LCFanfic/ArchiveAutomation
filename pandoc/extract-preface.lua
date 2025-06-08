local preface = {}
local found_break = false
local paragraph_count = 0

function Para(el)
  paragraph_count = paragraph_count + 1
  if paragraph_count <= 2 then
    -- title and summary are paragraph elements and always the first and second Para in the document.
    return el
  end

  if not found_break then
    table.insert(preface, el)
    return {}
  end

  return el
end

function Header(el)
  if not found_break then  
    found_break = true
  end

  return el  
end

function HorizontalRule(el)
  if not found_break then  
    found_break = true
    return {}
  end

  return el  
end

function Meta(meta)
  meta.preface = pandoc.MetaBlocks(preface)
  return meta
end
