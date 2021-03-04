module Wordcut

struct Key
    row_no::Int32
    offset::Int32
    ch::Char
end

struct NodePtr{T}
    row_no::Int32
    isfinal::Bool
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
            isfinal = length(word) == j
            if haskey(tab, key)
                nodeptr = tab[key]
                child_id = nodeptr.row_no
                row_no = child_id
             else
                 tab[key] = NodePtr{T}(Int32(i), isfinal, isfinal ? payload : nothing)
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

@enum LinkKind unk=1 dict=2 init=3 latin=4 punc=5

struct Link
    p::Int64
    w::Int64
    unk::Int64
    kind::LinkKind
end

function isbetter(l::Link, r::Link)::Bool
    if l.unk < r.unk
        return true
    end

    if l.w < r.w
        return true 
    end

    return false
end

@enum TransducerState waiting=1 activated=2 completed=3

struct LatinTransducer
    s::Int64
    e::Int64
    state::TransducerState
end

@inline function islatin(ch::Char)
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
end

function update(t::LatinTransducer, ch::Char, i::Int64, s::String)
    if t.state == waiting
        if islatin(ch)
            t.s = i
            t.state = activated
        end
    else
        if islatin(ch)
            if i == length(s) || !islatin(s[i + 1])
                t.e = i
                t.state = completed
            end
        else
            t.state = waiting
        end
    end
end

function create_link(t::LatinTransducer, path::Array{Link})::Union{Nothing, Link}
    if t.state == completed
        p_link = path[t.s]
        return Link(t.s, p_link.w + 1, p_link.unk, latin)
    else
        return nothing
    end
end

struct PuncTransducer
    s::Int64
    e::Int64
    state::TransducerState
end

function update(t::PuncTransducer, ch::Char, i::Int64, s::String)
    if t.state == waiting
        if ch == ' '
            t.s = i
        end
    else
        if ch == ' '
            if length(s) == i && s[i + 1] != " "
                t.e = i
                t.state = completed
            end
        else
            t.state = waiting
        end
    end
end

function create_link(t::PuncTransducer, path::Array{Link})::Union{Nothing, Link}
    if t.state == completed
        p_link = path[t.i]
        return Link{t.i, p_link.w + 1, p_link.unk, punc}
    end
    return nothing
end

struct DixPtr
    s::Int64
    row_no::Int64
    isfinal::Bool
end

function build_path(dix::PrefixTree{Int32}, s::String)::Array{Link}
    left_boundary = 1
    path::Array{Link} = [Link(1,0,0,init)]
    dix_ptrs::Array{DixPtr} = []
    i = 1
    for ch in s
        unk_link = path[left_boundary]
        link::Link = Link(left_boundary, unk_link.w + 1, unk_link.unk + 1, unk)
        
        push!(dix_ptrs, DixPtr(i, 1, false))
        j = 1        
        while j <= length(dix_ptrs)
            dix_ptr::DixPtr = dix_ptrs[j]
            offset = i - dix_ptr.s + 1
            println("CH = ", ch, " i = ", i, " j = ", j, " dix_ptr = ", dix_ptr, " offset = ", offset)
            child = lookup(dix, dix_ptr.row_no, offset, ch)
            println("child = ", child)
            if isnothing(child)
                if j == length(dix_ptrs)
                    j += 1
                    pop!(dix_ptrs)                    
                else
                    dix_ptrs[j] = dix_ptrs[length(dix_ptrs)]
                    pop!(dix_ptrs)
                end
            else
                dix_ptrs[j] = DixPtr(dix_ptr.s, child.row_no, child.isfinal)
                j += 1
            end
            for dix_ptr in dix_ptrs
                if dix_ptr.isfinal
                    dix_link = path[dix_ptr.s]
                     new_link = Link(dix_ptr.s, dix_link.w + 1, dix_link.unk, dict)
                     if isbetter(new_link, link)
                         link = new_link
                     end
                end
            end
        end
        push!(path, link)
        i += 1
    end
    return path
end

dix1 = Wordcut.make_prefix_tree([("กา", Int32(10)), ("กาม", Int32(20))])
println(build_path(dix1, "กา"))

end # module
