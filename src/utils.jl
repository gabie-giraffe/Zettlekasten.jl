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

list_tags(db::Database) = list_annotations(db, annotation_filter=:tag) .|> a -> a.text
list_ats(db::Database) = list_annotations(db, annotation_filter=:at) .|> a -> a.text
function stats(db::Database) 
    K = keys(db) |> collect |> sort
end


