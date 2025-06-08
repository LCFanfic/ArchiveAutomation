function Pandoc(doc)
  local output = "{\n"
  output = output .. "  \"filename\": \"" ..  pandoc.utils.stringify(doc.meta.filename) .. "\",\n"
  output = output .. "  \"title\": \"" ..  pandoc.utils.stringify(doc.meta.title) .. "\",\n"

  output = output .. "  \"authors\": [\n"
  local authornames_array = {}  
  for _, author in ipairs(doc.meta.author) do
    local name = pandoc.utils.stringify(author.name)
    local email = pandoc.utils.stringify(author.email)
    local url = pandoc.utils.stringify(author.url)

    if (#authornames_array > 0) then
      output = output .. ",\n"
    end

    output = output .. "    {\n"
    output = output .. "      \"name\": \"" .. name .. "\",\n"
    output = output .. "      \"email\": \"" .. email .. "\",\n"
    output = output .. "      \"url\": \"" .. url .. "\"\n"
    output = output .. "    }"

    table.insert(authornames_array, name)
  end
  output = output .. "\n"
  output = output .. "  ],\n"

  local authornames = nil  
  if #authornames_array == 0 then
    authornames = ""
  elseif #authornames_array == 1 then
    authornames = authornames_array[1]
  elseif #authornames_array == 2 then
    authornames = authornames_array[1] .. " and " .. authornames_array[2]
  else
    authornames = table.concat(authornames_array, ", ", 1, #authornames_array-1)
                  .. ", and " .. authornames_array[#authornames_array]
  end  
  output = output .. "  \"authornames-formatted\": \"" ..  authornames .. "\",\n"

  output = output .. "  \"rating\": \"" ..  pandoc.utils.stringify(doc.meta.rating) .. "\",\n"
  output = output .. "  \"date\": \"" ..  pandoc.utils.stringify(doc.meta.date) .. "\",\n"
  output = output .. "  \"length\": {\n"
  output = output .. "    \"words\": \"" .. pandoc.utils.stringify(doc.meta.length.words) .. "\",\n"
  output = output .. "    \"text\": \"" .. pandoc.utils.stringify(doc.meta.length.text) .. "\"\n"
  output = output .. "  },\n"
  output = output .. "  \"summary\": \"" ..  pandoc.utils.stringify(doc.meta.summary) .. "\"\n"
  output = output .. "}\n"

  return  pandoc.Pandoc({pandoc.RawBlock("plain", output)}, doc.meta)

end