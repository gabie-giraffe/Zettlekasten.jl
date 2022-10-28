module Zettlekasten

using Dates, Markdown, UUIDs

warn_about_unhandled_parts = false

include("Annotation.jl")
include("Entry.jl")

const Database = Vector{Entry}

include("collate-md-content.jl")
include("extract_annotations.jl")
include("tagline.jl")
include("parser.jl")

# TODO
# include("compile.jl")
# include("show.jl")
# include("utils.jl")

end # module
