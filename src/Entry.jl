mutable struct Entry
    uuid::UUID
    title::Union{Nothing, AbstractString}
    content::Vector{Any}
    annotations::Vector{Annotation}

    date::Union{Nothing, Date}
    source::Union{Nothing, AbstractString}
    
    subentries::Vector{Entry}

    Entry(
        content = Vector{Any}(), 
        annotations = Vector{Annotation}(); 
        date = nothing,
        title = nothing,
        source = nothing,
        subentries = Vector{Entry}()
    ) = new(uuid4(), title, content, annotations, date, source, subentries)
end

Base.copy(entry::Entry) = Entry(
    copy(entry.content), 
    copy(entry.annotations); 
    date = begin
        if typeof(entry.date) !== Nothing
            copy(entry.date)
        end
    end,
    title = begin
        if typeof(entry.title) !== Nothing
            copy(entry.title)
        end
    end,
    source = begin
        if typeof(entry.source) !== Nothing
            copy(entry.source)
        end
    end,
    subentries = copy(entry.subentries)
)
