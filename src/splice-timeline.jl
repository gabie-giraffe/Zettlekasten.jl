
using Markdown

include("collate-md-content.jl")

sluggify(s::AbstractString) = replace(lowercase(s), r"\s" => "-")

parse_tagline(s::AbstractString) = eachmatch(r"\|\s+\#((\w|-|\.|_)+)\s+\|", s, overlap = true) |> 
    collect .|> 
    m -> m[1]

make_tagline(tags::Vector{AbstractString}) = "| " * join(tags, " | ") * " |"

function all_markdown_files(path::AbstractString = ".", destination::AbstractString = "timeline")

    timeline_files = Dict{AbstractString, Vector{Any}}()
    tagline = Vector{AbstractString}()

    for (root, _, files) in walkdir(path)
        for file ∈ files

            # Skip extracted files
            if contains(file, r"extracted\.md$")
                continue
            end
            
            m = match(r"([^/]*)\.md$", file)
            if (typeof(m) != Nothing)                
                # TODO find how to add entry separator and slug to content

                path = joinpath(root, file)
                slug = sluggify(m[1])

                println("$path => $slug")

                source = Markdown.parse_file(path)
                main_content = Vector{Any}()

                previous_entry_name = ""
                entry_name = ""
                previous_was_time_entry = false
                processing_time_entry = false
                for part ∈ source.content
                    is_new_entry = typeof(part) == Markdown.Header{2}
                    part_text = collate(part)
                    if is_new_entry
                        tagline = Vector{AbstractString}([slug])
                        previous_entry_name = entry_name
                        entry_name = part_text
                        previous_was_time_entry = processing_time_entry
                        processing_time_entry = contains(entry_name, r"^\d{4}-\d{2}-\d{2}$")
                        
                        # Load existing entry file if it exists.
                        if processing_time_entry && entry_name ∉ keys(timeline_files)
                            destination_path = joinpath(destination, entry_name) * ".md"
                            if isfile(destination_path)
                                timeline_files[entry_name] = Markdown.parse_file(destination_path).content
                            else
                                timeline_files[entry_name] = Vector{Any}()
                            end
                        end
                    end

                    part_tags = parse_tagline(part_text)
                    if !isempty(part_tags)
                        push!(tagline, part_tags)
                        continue
                    end

                    # Add tagline at the end of the entry
                    if is_new_entry && !isempty(tagline)
                        tagline_part = make_tagline(tagline) |> Markdown.Paragraph
                        if previous_was_time_entry
                            push!(timeline_files[previous_entry_name], tagline_part)
                        else
                            push!(main_content, tagline_part)
                        end
                    end
                    if processing_time_entry
                        if is_new_entry && !isempty(timeline_files[entry_name])
                            if !isempty(tagline)
                                make_tagline(tagline) |> 
                                    Markdown.Paragraph |> 
                                    p -> push!(timeline_files[entry_name], p)
                            end

                            push!(timeline_files[entry_name], Markdown.HorizontalRule())
                        end
                        push!(timeline_files[entry_name], part)
                    else
                        push!(main_content, part)
                    end
                end

                # Flush the remaining tagline (if any)
                if !isempty(tagline)
                    tagline_part = make_tagline(tagline) |> Markdown.Paragraph
                    if processing_time_entry
                        push!(timeline_files[entry_name], tagline_part)
                    else
                        push!(main_content, tagline_part)
                    end
                end

                main_content = Markdown.MD(main_content)
                io = open("$path.extracted.md", "w")
                write(io, Markdown.plain(main_content));
                close(io);
            end
        end
    end

    for entry ∈ timeline_files
        date = entry.first
        entry_content = Markdown.MD(entry.second)
        entry_path = joinpath(destination, date) * ".md"

        io = open(entry_path, "w")
        write(io, Markdown.plain(entry_content));
        close(io);
    end

end