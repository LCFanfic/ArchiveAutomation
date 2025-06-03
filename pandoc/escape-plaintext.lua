function Str(el)
    local replacements = {
        ["%-%-%-"] = "--", -- m-dash should be rendered like n-dash
    }

    for typographic, markdown in pairs(replacements) do
        el.text = el.text:gsub(typographic, markdown)
    end

    return el
end

function Emph(el)
    return pandoc.Inlines({pandoc.Str("*")}):extend(el.content):extend({pandoc.Str("*")})
end

function Strong(el)
    return pandoc.Inlines({pandoc.Str("*")}):extend(el.content):extend({pandoc.Str("*")})
end