local json = require 'pandoc.json'

local title = nil
local author = nil
local submission_date = nil
local rating = nil
local summary = nil
local authors_table_file = nil
local filename = nil

-- Extract the first header into the title metadata and remove it from the document
-- Check that the remaning headers all have the same level and set the level to "Header 1"
local heading_level = nil
function Header(el)

  local text = pandoc.utils.stringify(el)

  -- strip empty headers
  if string.len(remove_whitespace(text)) == 0 then
    return {}
  end

  if not title then
    title = pandoc.MetaString(text)
	return {}
  end

  if not heading_level then
    heading_level = el.level
  elseif el.level ~= heading_level then
    io.stderr:write("Warning: Multiple heading levels detected!\n")
  end

  el.level = 1
  return el
end

local paragraph_count = 0
local first_line = nil
function Para(el)

  local text = pandoc.utils.stringify(el)
  local text_without_whitespace = remove_whitespace(text)

  -- strip empty paragraphs
  if string.len(text_without_whitespace) == 0 then
    return {}
  end	

  el.content = trim_trailing_nbsp(el.content)

  -- Whitelist known content lines without word-characters
  if text_without_whitespace == "…" or text_without_whitespace == "..." then -- elipsis
    return el
  elseif text_without_whitespace == "?" or text_without_whitespace == "!" then -- punctuation mark
    return el
  elseif text_without_whitespace == "-" or text_without_whitespace == "–" or text_without_whitespace == "—" then -- dash
    return el
  -- Check if the paragraph consists of mostly non-word characters
  elseif text:match("^%W+$") then 
    -- match lines that only contain NON-alpha-numerical characters
	-- by matching for uppercase W
    return pandoc.HorizontalRule()
  end
  
  paragraph_count = paragraph_count + 1

  if paragraph_count < 7 then
  io.stderr:write(paragraph_count .. " " .. text .. "\n")
  end

  -- Extract the author, rating, summission date, and summary
  if paragraph_count < 7 and has_linebreaks(el) then
    paragraph_count = paragraph_count - 1
    local paragraphs = {}
    local current_content = {}
   
    for _, content in ipairs(el.content) do
      if content.t == "LineBreak" then
        -- Create a new paragraph with the collected content so far
        table.insert(paragraphs, Para(pandoc.Para(current_content)))
        -- Reset content for the next paragraph
        current_content = {}
      else
        -- Keep adding inline content to the current paragraph
        table.insert(current_content, content)
      end
    end
   
    -- Add the last collected content as a paragraph if it's not empty
    if #current_content > 0 then
      table.insert(paragraphs, Para(pandoc.Para(current_content)))
    end
   
    return paragraphs
  elseif paragraph_count < 7 and string.lower(text):match("^by .-@") then
    author = pandoc.MetaString(string.sub(text, #"by.."))
	if first_line and not title then
	  title = first_line
	  first_line = nil
	end
    return {}
  elseif paragraph_count < 7 and string.lower(text):match("^rating: .") then
    rating = pandoc.MetaString(string.sub(text, #"rating:.."))
    return {}
  elseif paragraph_count < 7 and string.lower(text):match("^rated: .") then
    rating = pandoc.MetaString(string.sub(text, #"rated:.."))
    return {}
  elseif paragraph_count < 7 and string.lower(text):match("^submitted: .") then
    submission_date = pandoc.MetaString(string.sub(text, #"submitted:.."))
    return {}
  elseif paragraph_count < 7 and string.lower(text):match("^submission date: .") then
    submission_date = pandoc.MetaString(string.sub(text, #"submission date:.."))
    return {}
  elseif paragraph_count < 7 and string.lower(text):match("^summary: .") then
    summary = pandoc.MetaString(string.sub(text, #"summary:.."))
    return {}
  elseif paragraph_count == 1 then
    first_line = pandoc.MetaString(text)
    return {}
  elseif paragraph_count == 7 and first_line then
    summary = first_line
	  first_line = nil
    return el
  else
    if has_linebreaks(el) then
      io.stderr:write("Warning: linebreaks detected in paragraph " .. paragraph_count .. ".\n")
    end
    return el
  end

end

function Meta (meta)
  authors_table_file = meta.authorstable
  if not authors_table_file then
    io.stderr:write("Warning: No authors file has been provided via 'authorstable' metadata.\n")
  end

  filename = meta.filename
  if not filename then
    io.stderr:write("Warning: No file name has been provided via 'filename' metadata.\n")
  end

  return meta
end

function Pandoc(doc)
  local yaml_frontmatter = "---\n"
 
  if filename then
    yaml_frontmatter = yaml_frontmatter .. "filename: " .. filename .. "\n"
  else
    yaml_frontmatter = yaml_frontmatter .. "filename: input\n"
  end

  if title then
    yaml_frontmatter = yaml_frontmatter .. "title: >\n" .. wrap_text(title, 80, 4) .. "\n"
  end

  if author then
    local authors_table = read_json_file(authors_table_file)
    local authors = process_authors(author, authors_table)
    yaml_frontmatter = yaml_frontmatter .. "author: \n"
    for _, v in ipairs(authors) do
      yaml_frontmatter = yaml_frontmatter .. "  - name: "  .. v.name .. "\n"
      yaml_frontmatter = yaml_frontmatter .. "    email: " .. v.email .. "\n"
      yaml_frontmatter = yaml_frontmatter .. "    url: "   .. v.url .. "\n"
    end  
  end

  if rating then
    yaml_frontmatter = yaml_frontmatter .. "rating: " .. rating .. "\n"
  end

  if submission_date then
    local parsed_date = parse_date(submission_date)
    yaml_frontmatter = yaml_frontmatter .. "date: " .. string.format("%04d-%02d-%02d", parsed_date.year, parsed_date.month, parsed_date.day) .. "\n"
    yaml_frontmatter = yaml_frontmatter .. "dateformatted: " .. submission_date .. "\n"
  end

  local length_in_words = count_words_in_doc(doc)
  local length_in_words_formatted = format_number(length_in_words)

  local length_in_bytes = count_characters_in_doc(doc)
  length_in_bytes = length_in_bytes * 1.03 -- increase by averaged factor for linebreak and formatting in plain text
  local length_in_bytes_formatted = nil
  if length_in_bytes > 1024 then 
    length_in_bytes_formatted = format_number(math.floor((length_in_bytes / 1024 + 0.5))) .. " kB"
  elseif length_in_bytes >= 1000 then
    length_in_bytes_formatted = "1 kB"
  else
    length_in_bytes_formatted = length_in_bytes .. " bytes"
  end

  yaml_frontmatter = yaml_frontmatter .. "length:\n"
  yaml_frontmatter = yaml_frontmatter .. "  words: " .. length_in_words_formatted .. "\n" 
  yaml_frontmatter = yaml_frontmatter .. "  text: " .. length_in_bytes_formatted .. "\n"

  if summary then
    yaml_frontmatter = yaml_frontmatter .. "summary: >\n" .. wrap_text(summary, 80, 4) .. "\n"
  end

  yaml_frontmatter = yaml_frontmatter .. "---\n"

  local yaml_block = pandoc.RawBlock("markdown", yaml_frontmatter)
  table.insert(doc.blocks, 1, yaml_block)

  return doc
end


function process_authors (value, authors_table)
  local result = {}
  value = string.gsub(value, " and ", ", ")
  for name_and_email in value:gmatch("[^,]+") do
    local name, email = name_and_email:match("^(.*)%s+(%S+)$") -- Split on last space
    name = name:match("^%W*(.-%.?)%W*$") -- Trim all non-alphanumerics. Keep the trailing period.
    email = string.lower(email:match("^%W*(.-)%W*$")) -- Trim all non-alphanumerics.

    local author = authors_table[email]
    if not author then
      io.stderr:write("Warning: No author found for e-mail '" .. email .. "'.\n")
      author = {name = name, email = email, url = ""}
    end
    author.email = email

    table.insert(result, author)
  end
  return result
end


function wrap_text(text, width, indent)
  local wrapped = ""
  local line = ""
  local indent_text = string.rep(" ", indent)

  for word in text:gmatch("%S+") do
    if #line + #"." + #word > width - indent then
      wrapped = wrapped .. indent_text .. line .. "\n"
      line = word
    else
      line = (line == "" and word) or (line .. " "  .. word)
    end
  end

  wrapped = wrapped .. indent_text .. line
  return wrapped
end


function count_words_in_doc(doc)
  local word_count = 0

  local function count_words(block)
    if block.t == "Str" then
      word_count = word_count + 1
    elseif block.t == "Space" then
      -- Spaces separate words, no increment needed
    end
  end

  -- Iterate through all document blocks
  for _, block in ipairs(doc.blocks) do
    if block.t == "Para" or block.t == "Header" or block.t == "Plain" then
      for _, word in ipairs(block.content) do
        count_words(word)
      end
    end
  end

  return word_count
end


function count_characters_in_doc(doc)
  local char_count = 0

  local function utf8_character_count(text)
    local _, count = text:gsub("[^\128-\191]", "")  -- Matches UTF-8 leading bytes
    return count
  end

  local function count_characters(block)
    if block.t == "Str" then
      char_count = char_count + utf8_character_count(block.text) + 1 -- include the space or newline
    end
  end

  -- Iterate through all document blocks
  for _, block in ipairs(doc.blocks) do
    if block.t == "Para" or block.t == "Header" or block.t == "Plain" then
      for _, element in ipairs(block.content) do
        count_characters(element)
      end
    end
  end

  return char_count
end


function format_number(n)
  local formatted = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return formatted:gsub("^,", "")  -- Remove leading comma
end


function parse_date(date_string)
  local month_name, year = date_string:match("(%a+) (%d+)")

  local months = {
    January = 1, February = 2, March = 3, April = 4, May = 5, June = 6,
    July = 7, August = 8, September = 9, October = 10, November = 11, December = 12
  }

  if months[month_name] then
    return { year = tonumber(year), month = months[month_name], day = 1 }
  else
    return { year = tonumber(year), month = 1, day = 1 }
  end
end


function remove_whitespace(s)
  return s:gsub("[%s\u{00A0}]+", "")  -- Replace all whitespace with an empty string
end


function has_linebreaks(el)
  for _, content in ipairs(el.content) do
    if content.t == "LineBreak" then
      return true
    end
  end

  return false
end


function trim_trailing_nbsp(inlines)
  -- Iterate in reverse to remove trailing nbsp
  for i = #inlines, 1, -1 do
    local item = inlines[i]
    if item.t == "Str" then
      inlines[i] = pandoc.utils.stringify(item):gsub("[%s\u{00A0}]+$", "") -- Trim trailing spaces

      -- Remove empty strings if trimming made them empty
      if inlines[i] == "" then
        table.remove(inlines, i)
      else
        break -- Stop processing when a valid non-whitespace character remains
      end
    elseif item.t == "Space" then
      table.remove(inlines, i) -- Remove trailing Space elements
    else
      break -- Stop processing when encountering a non-space element
    end
  end
  return inlines
end


function read_json_file(filename)
  if not filename then
    io.stderr:write("Warning: Could not open file because filename is nil.\n")
    return {}
  end

  local file = io.open(filename, "r")
  if not file then
    io.stderr:write("Warning: Could not open file '" .. filename .. "'.\n")
    return {}
  end  

  local content = file:read("*a")
  file:close()
  return json.decode(content)
end