local first_heading = nil

function Header(el)
  if not first_heading then
    first_heading = pandoc.MetaString(pandoc.utils.stringify(el))
  end

  return el
end

function Meta(meta)
  meta.first_heading = first_heading
  return meta
end