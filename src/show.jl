
# function Base.show(io::IO, entry::Entry) 
#     print(io)
# end

function entry2md(entry::Entry, level::Int = 1)
    md = Markdown.MD()

    if entry.title !== nothing
        push!(md.content, Markdown.Header{level}(entry.title))
    elseif entry.date !== nothing
        push!(md.content, Markdown.Header{level}(entry.date))
    end

    push!(md.content, entry.content...)

    for subentry ∈ entry.subentries
        submd = entry2md(subentry, level + 1)

        push!(md.content, submd.content...)
    end

    return md
end