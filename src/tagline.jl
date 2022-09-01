const tag_element_pattern = r"\|\s+\#((\w|-|\.|_)+)\s+\|"
const tag_line_pattern = r"^(\|\s+\#((\w|-|\.|_)+)\s+)+\|$"

is_tagline(s::AbstractString) = contains(s, tag_line_pattern)
is_tagline(paragraph::Markdown.Paragraph) = collate(paragraph) |> is_tagline
is_tagline(_::Any) = false

parse_tagline(s::AbstractString) = eachmatch(tag_element_pattern, s, overlap = true) |> 
    collect .|> 
    m -> m[1]

parse_tagline(paragraph::Markdown.Paragraph) = collate(paragraph) |> parse_tagline
parse_tagline(_::Any) = []

make_tagline(entries::Vector) = (entries .|> tag -> "#$tag") |> 
    tags -> "| " * join(tags, " | ") * " |"