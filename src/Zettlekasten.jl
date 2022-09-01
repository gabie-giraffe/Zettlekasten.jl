module Zettlekasten

using Markdown

warn_about_unhandled_parts = false

include("extract_annotations.jl")
include("collate-md-content.jl")
include("tagline.jl")

const markdown_pattern = r"([^/]*)\.md$"
const date_entry_pattern = r"^\d{4}-\d{2}-\d{2}$"

Entry = NamedTuple{(:content, :annotations), Tuple{Vector{Any}, Vector{Any}}}
Topic = Vector{Entry}
Database = Dict{AbstractString, Topic}

Base.copy(entry::Entry) = make_entry(copy(entry.content), copy(entry.annotations))
make_entry(content::Vector{Any} = Vector{Any}(), annotations::Vector{Any} = Vector{Any}()) = (content = content, annotations = annotations)
make_slug(s::AbstractString) = replace(lowercase(s), r"\s" => "-")

function push_tagline!(entry::Entry, tagline::Vector{AbstractString}) 
    if !isempty(tagline)
        push!(entry.content, Markdown.Paragraph(make_tagline(tagline)))
    end
end

function index(path::AbstractString = "."; exclusion::Vector = [])
    exclusion = exclusion ∪ [
        r"/\." # Any path with en element starting with '.' (.git, .DS_Store, ...)
    ]

    database = Database()

    for (root, _, files) ∈ walkdir(path)
        for file ∈ files
            filepath = joinpath(root, file)

            # Apply exclusion list
            if 1 ∈ contains.(filepath, exclusion)
                continue
            end

            m = match(r"([^/]*)\.md$", file)
            if(typeof(m) != Nothing)
                slug = make_slug(m[1])
                Markdown.parse_file(filepath) |> md -> index!(database, md, slug)
            end
        end
    end

    return database
end

@enum StateTest main_entry date_entry

function index!(database::Database, md::Markdown.MD, main_slug::AbstractString)
    current_topic = main_slug
    current_state = main_entry
    start_new_entry = false
    drop_part = false
    tagline = Vector{AbstractString}()

    for part ∈ md.content
        ## Detect the change of topic.
        if typeof(part) <: Markdown.Header{2}            
            title = collate(part)

            ## Paste the tagline before changing topic/entry.
            if current_topic != main_slug
                pushfirst!(tagline, main_slug)
            end
            if !isempty(tagline) && !isempty(database[current_topic])
                push!(database[current_topic][end].content, Markdown.Paragraph(make_tagline(tagline)))
            end
            tagline = Vector{AbstractString}()

            if (contains(title, date_entry_pattern))
                start_new_entry = true
                current_topic = make_slug(title)
                current_state = date_entry
                drop_part = true
            else
                current_topic = main_slug
                current_state = main_entry
            end
        end

        ## Detect a new entry in the current topic.
        if typeof(part) <: Markdown.HorizontalRule
            ## Paste the tagline before changing entry.
            if current_topic != main_slug
                pushfirst!(tagline, main_slug)
            end
            if !isempty(tagline) && !isempty(database[current_topic])
                push!(database[current_topic][end].content, Markdown.Paragraph(make_tagline(tagline)))
            end
            tagline = Vector{AbstractString}()

            start_new_entry = true
            drop_part = true
        end

        ## Cut the tagline out so it can be moved to the end of the entry.
        if is_tagline(part)
            tagline = tagline ∪ parse_tagline(part)
            drop_part = true
        end

        ## Stub out a new topic if needed.
        if current_topic ∉ keys(database)
            database[current_topic] = Topic()
            start_new_entry = true
        end

        ## Stub out a new entry if needed.
        if start_new_entry
            start_new_entry = false
            push!(database[current_topic], make_entry())
        end

        ## Add the current part to the records.
        if !drop_part
            push!(database[current_topic][end].content, part)
        else
            drop_part = false
        end
        
        ## Scrape annotations
        part_annotations = extract_annotations(part)
        if current_state == date_entry
            push!(part_annotations, make_tag_annotation(main_slug))
        end
        push!(database[current_topic][end].annotations, part_annotations...)
    end

    ## Paste the tagline before changing file.
    if current_topic != main_slug
        pushfirst!(tagline, main_slug)
    end
    if !isempty(tagline) && !isempty(database[current_topic])
        push!(database[current_topic][end].content, Markdown.Paragraph(make_tagline(tagline)))
    end

    return database
end

stats(db::Database) = keys(db) |> collect |> sort .|> k -> k => length(db[k])

function compile(db::Database, key::AbstractString)
    title = nothing
    compiled_topic = Topic()

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

function compile(topic::Topic; title::Union{Nothing, AbstractString} = nothing)
    md = Markdown.MD()

    if typeof(title) <: AbstractString
        push!(md.content, Markdown.Header{1}(title))
    end

    for entry ∈ topic
        push!(md.content, entry.content...)
        push!(md.content, Markdown.HorizontalRule())
    end

    if typeof(md.content[end]) <: Markdown.HorizontalRule
        pop!(md.content)
    end

    return md
end

function list_annotations(db::Database; annotation_filter::Union{Nothing, Symbol} = nothing)
    annotations = []
    for topic ∈ db
        for entry ∈ topic.second
            if typeof(annotation_filter) <: Symbol
                push!(annotations, filter(a->a.type == annotation_filter, entry.annotations)...)
            else
                push!(annotations, entry.annotations...)
            end
        end
    end

    return annotations |> unique
end

list_ats(db::Database) = list_annotations(db, annotation_filter=:at) .|> a -> a.text
list_tags(db::Database) = list_annotations(db, annotation_filter=:tag) .|> a -> a.text

end # module
