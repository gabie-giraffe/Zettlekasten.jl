module Zettlekasten

using Dates, Markdown

warn_about_unhandled_parts = false

include("Annotation.jl")
include("Entry.jl")

const Database = Dict{AbstractString, Entry}

include("collate-md-content.jl")
include("extract_annotations.jl")
include("tagline.jl")
include("parser.jl")

# TODO
# include("compile.jl")
# include("utils.jl")

end # module
