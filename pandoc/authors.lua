function Meta(meta)
  if meta.author and type(meta.author) == "table" then
    local formatted_authors_array = {}

    for _, author in ipairs(meta.author) do
      if author.name and author.email and author.url then
        local name = pandoc.utils.stringify(author.name)
        local email = pandoc.utils.stringify(author.email)
        local url = pandoc.utils.stringify(author.url)

        table.insert(formatted_authors_array, "[" .. name .. "](" .. url .. ") <<" .. email .. ">>")
      end
    end

    local formatted_authors_string = nil  
    if #formatted_authors_array == 0 then
	  formatted_authors_string = ""
    elseif #formatted_authors_array == 1 then
      formatted_authors_string = formatted_authors_array[1]
    elseif #formatted_authors_array == 2 then
      formatted_authors_string = formatted_authors_array[1] .. "and\\\n" .. formatted_authors_array[2]
    else
      formatted_authors_string = table.concat(formatted_authors_array, ",\\\n", 1, #formatted_authors_array-1)
                                 .. ", and\\\n" .. formatted_authors_array[#formatted_authors_array]
	end

    meta.authors_formatted =  pandoc.RawInline("markdown", formatted_authors_string)
  end

  return meta
end