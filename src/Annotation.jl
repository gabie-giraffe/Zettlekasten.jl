@enum AnnotationType at tag

struct Annotation
    type::AnnotationType
    text::AbstractString
    value::Union{Nothing, AbstractString}

    Annotation(
        type::AnnotationType,
        text::AbstractString,
        value::Union{Nothing, AbstractString} = nothing
    ) = new(type, text, value)
end