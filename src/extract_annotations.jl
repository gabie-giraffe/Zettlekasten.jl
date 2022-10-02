const annotation_pattern = r"(^|\s)([@#])((\w|-)+)(\:((\w|-)+))?"

function extract_annotations(text::AbstractString)
    matches = Vector{Annotation}()
    for match ∈ eachmatch(annotation_pattern, text)
        annotation_text = lowercase(match[3])

        annotation_value = match[6]
        if annotation_value !== nothing
            annotation_value = lowercase(annotation_value)
        end

        if (match[2] == "@") 
            push!(matches, Annotation(at, annotation_text, annotation_value))
        end
        if (match[2] == "#") 
            push!(matches, Annotation(tag, annotation_text, annotation_value))
        end
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