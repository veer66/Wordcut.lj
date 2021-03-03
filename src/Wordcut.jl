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

end # module
