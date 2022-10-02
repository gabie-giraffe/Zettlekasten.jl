function compile(db::Database, key::AbstractString)
    title = nothing
    compiled_topic = Entry()

    sorted_topic_names = keys(db) |> collect |> sort |> reverse

    if key ∈ sorted_topic_names
        push!(compiled_topic, db[key]...)
    else
        title = key
    end

    for topic_name ∈ sorted_topic_names
        last_title = ""
        topic_entries = db[topic_name]
        for entry ∈ topic_entries
            annotations = entry.annotations .|> a -> a.text |> lowercase
            if lowercase(key) ∈ annotations
                entry_copy = copy(entry)
                if contains(topic_name, date_entry_pattern) 
                    if last_title != topic_name
                        pushfirst!(entry_copy.content, Markdown.Header{2}(topic_name))
                        last_title = topic_name
                    end
                else
                    if is_tagline(entry_copy.content[end])
                        tagline = pop!(entry_copy.content) |> parse_tagline
                        pushfirst!(tagline, topic_name)
                        push!(entry_copy.content, make_tagline(tagline))
                    else
                        push!(entry_copy.content, make_tagline([topic_name]))
                    end
                    last_title = ""
                end

                push!(compiled_topic, entry_copy)
            end
        end
    end

    compile(compiled_topic; title = title)
end

function compile(parententry::Entry; title::Union{Nothing, AbstractString} = nothing)
    md = Markdown.MD()

    if typeof(title) <: AbstractString
        push!(md.content, Markdown.Header{1}(title))
    end

    for entry ∈ parententry.subentries
        push!(md.content, entry.content...)
        push!(md.content, Markdown.HorizontalRule())
    end

    if typeof(md.content[end]) <: Markdown.HorizontalRule
        pop!(md.content)
    end

    return md
end