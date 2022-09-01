
function collate(parts::Vector)
    text_parts = parts .|> p -> !(typeof(p) <: AbstractString) ? collate(p) : p
    string(text_parts...)
end

function collate(part::Any)
    if Zettlekasten.warn_about_unhandled_parts
        part_type = typeof(part)
        @warn "Unhandled segment type for collation: $part_type"
    end

    return ""
end

collate(part::Markdown.Header) = collate(part.text)
collate(part::Markdown.Paragraph) = collate(part.content)
collate(part::Markdown.Italic) = part.text |> collate |> x -> "_$(x)_"
collate(part::Markdown.Bold,) = part.text |> collate |> x -> "**$(x)**"
collate(part::Markdown.Link) = part.text |> collate

collate(part::Markdown.Code) = part.code |> collate

collate(part::AbstractString) = part
collate(part::Number) = string(part)