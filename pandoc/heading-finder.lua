local first_heading = nil
function Header(el)

  local text = pandoc.utils.stringify(el)

  if not first_heading then
    first_heading = pandoc.MetaString(text)
  end

  return el
end
