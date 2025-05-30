local preface = {}
local found_break = false
local paragraph_count = 0

function Para(el)
  paragraph_count = paragraph_count + 1
  if paragraph_count == 1 then
    -- summary is a paragraph element and always the first Para in the document.
    return el
  end

  if not found_break then
    table.insert(preface, el)
    return {}
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
