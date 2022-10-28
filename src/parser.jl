const date_entry_pattern = r"^\d{4}-\d{2}-\d{2}$"

"Parse a repository of Markdown notes."
function parse_repository(path::AbstractString = "."; exclusion::Vector = [])
    number_of_files_parsed = 0

    entries = Vector{Entry}()
    exclusion = exclusion ∪ [
        r"/\." # Any path with en element starting with '.' (.git, .DS_Store, ...)
    ]

    for (root, _, files) ∈ walkdir(path)
        for file ∈ files
            source = joinpath(root, file)
            
            # Apply exclusion list
            if 1 ∈ contains.(source, exclusion)
                continue
            end

            m = match(r"([^/]*)\.md$", file)
            if(typeof(m) != Nothing)
                number_of_files_parsed += 1
                @debug "Parsing Markdown file." source
                
                entry = Markdown.parse_file(source) |> md -> parse(md; source, title=m[1])
                
                # Only add the entry if it has content.
                if length(entry.content) > 0 || length(entry.subentries) > 0
                    push!(entries, entry)
                else
                    @debug "No content found in Markdown file." source=source
                end
            end
        end
    end

    @info "Finished parsing repositry." number_of_files_parsed number_of_entries=length(entries)

    return entries
end

"Parse a single Markdown document."
function parse(md::Markdown.MD; source::Union{Nothing, AbstractString} = nothing, title::Union{Nothing, AbstractString} = nothing)
    content = copy(md.content)
    root_entry = Entry()
    root_entry.source = source

    set_title_or_date(root_entry, title)
    @info get_title_or_date(root_entry)

    return make_entry!(content, root_entry)
end

"Make an Entry from Markdown content."
function make_entry!(content::Vector{Any}, root_entry::Entry; depth::Int = 0)
    active_entry = add_subentry!(root_entry)

    while length(content) > 0
        part = popfirst!(content)

        # A Header and HorizontalRule indicate a change of entry
        part_type = typeof(part)
        if part_type <: Union{Markdown.Header, Markdown.HorizontalRule}
            if part_type <: Markdown.Header
                header_text = collate(part.text)
                level = typeof(part).parameters[begin]
                
                # A header level that is deeper then `depth` indicates a sub-entry.
                if level > depth
                    set_title_or_date(active_entry, header_text)
                    active_entry = make_entry!(content, active_entry; depth=level)
                    root_entry.subentries[end] = active_entry
                    @debug "Parsed Sub-Entries." depth make_log_context(root_entry, active_entry)...
                    
                # A header level that is the same depth as `depth` inticates a sibling entry.
                elseif level == depth
                    active_entry = add_subentry!(root_entry; header_text=header_text)
                    @debug "Added Sibling Entry." depth make_log_context(root_entry, active_entry)...

                # A header level that is shallower than `depth` is the responsibility of the parent call.
                else
                    @debug "End of Sub-Entry." depth make_log_context(root_entry, active_entry)...
                    pushfirst!(content, part)
                    return root_entry
                end
            end

            # A horizontal rule inticates a sibling entry.
            if part_type <: Markdown.HorizontalRule
                active_entry = add_subentry!(root_entry)
                @debug "Added Sibling Entry." depth make_log_context(root_entry, active_entry)... 
            end

            # After dealing with a change of entry, we're ready for the next part.
            continue
        end

        # When we get here, the current part belongs to the active entry.
        push!(active_entry.annotations, extract_annotations(part)...)
        
        ## Taglines are added to the annotations; they are not needed in the content.
        if is_tagline(part)
            @debug "Dropping tagline." depth make_log_context(root_entry, active_entry)...
            continue
        end
        
        push!(active_entry.content, part)
        @debug "Added part to Active Entry." depth make_log_context(root_entry, active_entry)...
    end

    @debug "Finished content." depth make_log_context(root_entry, root_entry)...

    # Flatten structure when the root is just wrapper for a single sub-entry.
    if length(root_entry.content) == 0 && length(root_entry.subentries) == 1
        root_entry = pop!(root_entry.subentries)

        @debug "Flattened content." depth make_log_context(root_entry, root_entry)...
    end

    return root_entry
end

"Prepare a child Entry."
function add_subentry!(root_entry::Entry = Entry(); header_text::Union{Nothing, AbstractString} = nothing)
    entry = Entry()
    entry.annotations = copy(root_entry.annotations)
    entry.date = root_entry.date
    entry.source = root_entry.source

    set_title_or_date(entry, header_text, get_title_or_date(root_entry))

    push!(root_entry.subentries, entry)
    @debug "Added Sub-Entry." make_log_context(root_entry, entry)...

    return entry
end

function set_title_or_date(entry::Entry, header_text::Union{Nothing, AbstractString} = nothing, default::Union{Nothing, AbstractString} = nothing)
    if header_text === nothing
        header_text = default
    end

    if typeof(header_text) <: AbstractString && contains(header_text, date_entry_pattern)
        entry.date = Date(header_text)
    elseif typeof(header_text) <: AbstractString
        entry.title = header_text
        # push!(entry.annotations, Annotation(tag, make_annotation_slug(title)))
    end
end

get_title_or_date(entry::Entry) = filter(x -> x !== nothing, [entry.title, entry.date |> string, entry.source]) |> first

"Make an annotation slug from a string."
make_annotation_slug(s::AbstractString) = replace(lowercase(s), r"\s" => "-")

make_log_context(root_entry::Entry, active_entry::Entry) = (
    root_entry_uuid = root_entry.uuid,
    root_entry_source = root_entry.source,
    root_entry_title = get_title_or_date(root_entry),
    root_entry_size = length(root_entry.content),
    root_entry_subentries = length(root_entry.subentries),
    root_entry_annotations = length(root_entry.annotations),
    
    active_entry_uuid = active_entry.uuid,
    active_entry_source = active_entry.source,
    active_entry_title = get_title_or_date(active_entry),
    active_entry_size = length(active_entry.content),
    active_entry_subentries = length(active_entry.subentries),
    active_entry_annotations = length(active_entry.annotations),
)
