const date_entry_pattern = r"^\d{4}-\d{2}-\d{2}$"

function parse_repository(path::AbstractString = "."; exclusion::Vector = [])
    entries = Vector{Entry}()
    exclusion = exclusion ∪ [
        r"/\." # Any path with en element starting with '.' (.git, .DS_Store, ...)
    ]

    for (root, _, files) ∈ walkdir(path)
        for file ∈ files
            filepath = joinpath(root, file)

            # Apply exclusion list
            if 1 ∈ contains.(filepath, exclusion)
                continue
            end

            m = match(r"([^/]*)\.md$", file)
            if(typeof(m) != Nothing)
                entry = Markdown.parse_file(filepath) |> md -> parse(md; source=filepath, title=m[1])

                # Only add the entry if it has content.
                if length(entry.content) > 0 || length(entry.subentries) > 0
                    push!(entries, entry)
                end
            end
        end
    end

    return entries
end

@enum ParserState main_entry date_entry

function parse(md::Markdown.MD; source::Union{Nothing, AbstractString} = nothing, title::Union{Nothing, AbstractString} = nothing)
    content = copy(md.content)
    root_entry = Entry()
    root_entry.source = source

    if typeof(title) !== Nothing && contains(title, date_entry_pattern)
        root_entry.date = Date(title)
    else
        root_entry.title = title
    end

    return parse!(content, root_entry)
end

function parse!(content::Vector{Any}, root_entry::Entry; depth::Int = 0)
    active_entry = add_entry!(root_entry)

    while length(content) > 0
        part = popfirst!(content)

        # A Header and HorizontalRule indicate a change of entry
        part_type = typeof(part)
        if part_type <: Union{Markdown.Header, Markdown.HorizontalRule}
            if part_type <: Markdown.Header
                level = typeof(part).parameters[begin]

                # A header level that is deeper then `depth` indicates a sub-entry.
                if level > depth
                    root_entry.subentries[end] = parse!(content, active_entry; depth=level)

                # A header level that is the same depth as `depth` inticates a sibling entry.
                elseif level == depth
                    active_entry = add_entry!(root_entry; title=collate(part.text))

                # A header level that is shalower than `depth` is the responsibility of the parent call.
                else
                    pushfirst!(content, part)
                    return root_entry
                end
            end

            # A horizontal rule inticates a sibling entry.
            if part_type <: Markdown.HorizontalRule
                active_entry = add_entry!(root_entry)
            end

            # After dealing with a change of entry, we're ready for the next part.
            continue
        end

        # When we get here, the current part belongs to the active entry.
        push!(active_entry.annotations, extract_annotations(part)...)

        ## Taglines are added to the annotations; they are not needed in the content.
        if is_tagline(part)
            continue
        end

        push!(active_entry.content, part)
    end

    # Flatten structure when the root is just wrapper for a single sub-entry.
    if length(root_entry.content) == 0 && length(root_entry.subentries) == 1
        root_entry = pop!(root_entry.subentries)
    end

    return root_entry
end


function add_entry!(root_entry::Entry = Entry(); title::Union{Nothing, AbstractString} = nothing)
    entry = Entry()
    entry.annotations = copy(root_entry.annotations)
    entry.date = root_entry.date
    entry.source = root_entry.source

    if typeof(title) <: AbstractString && contains(title, date_entry_pattern)
        entry.date = Date(title)
    elseif typeof(title) <: AbstractString
        entry.title = title
        push!(entry.annotations, Annotation(tag, make_slug(title)))
    end

    push!(root_entry.subentries, entry)
    return entry
end

make_slug(s::AbstractString) = replace(lowercase(s), r"\s" => "-")