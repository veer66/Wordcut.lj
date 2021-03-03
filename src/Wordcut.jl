module Wordcut

struct Key
    row_no::Int32
    offset::Int32
    ch::Char
end

struct NodePtr{T}
    row_no::Int32
    is_final::Bool
    payload::Union{Nothing,T}
end

struct PrefixTree{T}
    tab::Dict{Key,NodePtr{T}}
end

function make_prefix_tree(sorted_word_with_payload::Array{Tuple{String,T}})::PrefixTree{T} where {T}
    tab = Dict{Key,NodePtr{T}}()
    for i in 1:length(sorted_word_with_payload)        
        word, payload = sorted_word_with_payload[i]
        row_no = 1
        j = 1
        for word_idx in eachindex(word)
            ch = word[word_idx]
            key = Key(row_no, j, ch)
            is_final = length(word) == j
            if haskey(tab, key)
                nodeptr = tab[key]
                child_id = nodeptr.row_no
                row_no = child_id
             else
                 tab[key] = NodePtr{T}(Int32(i), is_final, is_final ? payload : nothing)
                 row_no = i
             end
            j += 1
        end
    end
    return PrefixTree(tab)
end

function lookup(tree::PrefixTree, row_no, offset, ch::Char)::Union{Nothing,NodePtr}
    key = Key(Int32(row_no), Int32(offset), ch)
    if haskey(tree.tab, key)
        return tree.tab[key]
    else
        return nothing
    end
end

@enum LinkKind latin=1

struct Link
    p::Int64
    w::Int64
    unk::Int64
    kind::LinkKind
end

function isbetter(l::Link, r::Link)::Bool
    if r.unk < l.unk
        return true
    end

    if r.w < l.w
        return true 
    end

    return false
end

struct LatinTransducer
    s::Int64
    e::Int64
    flag::Bool
end

@inline function islatin(ch::Char)
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
end

function update(t::LatinTransducer, ch::Char, i::Int64, s::String)
    if !t.flag
        if islatin(ch)
            t.s = i
            t.flag = true
        end
    else
        if islatin(ch)
            if i == length(s) || !islatin(s[i + 1])
                t.e = i
            end
        else
            t.flag = false
        end
    end
end

function create_link(t::LatinTransducer, path::Array{Link})::Union{Nothing, Link}
    if t.flag
        p_link = path[t.s]
        return Link(t.s, p_link.w + 1, p_link.unk, latin)
    else
        return nothing
    end
end

#struct Punc



end # module
