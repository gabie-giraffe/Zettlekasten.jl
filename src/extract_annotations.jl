
Annotation = NamedTuple{(:text, :type), Tuple{AbstractString, Symbol}}
make_at_annotation(text::AbstractString) = (text = text, type = :at)
make_tag_annotation(text::AbstractString) = (text = text, type = :tag)

function extract_annotations(text::AbstractString)
    matches = Vector()
    for match ∈ eachmatch(r"(^|\s)([@#])((\w|-)+)", text)
        annotation_text = lowercase(match[3])
        if (match[2] == "@") 
            push!(matches, make_at_annotation(annotation_text))
        end
        if (match[2] == "#") 
            push!(matches, make_tag_annotation(annotation_text))
        end
    end

    for match ∈ eachmatch(r"\[\[(.+)\]\]", text)
        annotation_text = lowercase(match[1])
        push!(matches, (
            text = annotation_text,
            type = :link
        ))
    end

    return matches
end

function extract_annotations(parts::Vector)
    if length(parts) > 0
        union(extract_annotations.(parts)...)
    else
        return []
    end
end

function extract_annotations(part::Any)
    if Zettlekasten.warn_about_unhandled_parts
        part_type = typeof(part)
        @warn "Unhandled segment type: $part_type"
    end

    return []
end

extract_annotations(part::Markdown.Paragraph) = collate(part.content) |> extract_annotations
extract_annotations(part::Markdown.BlockQuote) = collate(part.content) |> extract_annotations
extract_annotations(part::Markdown.Admonition) = collate(part.content) |> extract_annotations

extract_annotations(part::Markdown.Code) = part.code |> extract_annotations

extract_annotations(part::Markdown.Header) = collate(part.text) |> extract_annotations
extract_annotations(part::Markdown.Footnote) = collate(part.text) |> extract_annotations

extract_annotations(part::Markdown.List) = part.items |> extract_annotations
extract_annotations(::Markdown.HorizontalRule) = []