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
    ch_i::Int64
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

mutable struct LatinTransducer
    s::Int64
    e::Int64
    state::TransducerState
    link_kind::LinkKind
end

@inline function islatin(ch::Char)
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
end

function update(t::LatinTransducer, ch::Char, i::Int64, s::String)
    if t.state == waiting
        if islatin(ch)
            t.s = i
            t.state = activated
            if i == length(s) || !islatin(s[i + 1])
                t.e = i
                t.state = completed
            end
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

mutable struct PuncTransducer
    s::Int64
    e::Int64
    state::TransducerState
    link_kind::LinkKind
end

function update(t::PuncTransducer, ch::Char, i::Int64, s::String)
    if t.state == waiting
        if ch == ' '
            t.s = i
            t.state = activated
            if length(s) == i || s[i + 1] != " "
                t.e = i
                t.state = completed
            end            
        end
    else
        if ch == ' '
            if length(s) == i || s[i + 1] != " "
                t.e = i
                t.state = completed
            end
        else
            t.state = waiting
        end
    end
end

struct DixPtr
    s::Int64
    row_no::Int64
    isfinal::Bool
end

function build_path(dix::PrefixTree{Int32}, s::String)::Array{Link}
    transducers = [PuncTransducer(0,0,waiting,punc),LatinTransducer(0,0,waiting,latin)]
    left_boundary = 1
    path::Array{Link} = [Link(1,0,0,init,0)]
    dix_ptrs::Array{DixPtr} = []
    i = 1
    for ch_i in eachindex(s)
        ch = s[ch_i]
        unk_link = path[left_boundary]
        link::Link = Link(left_boundary, unk_link.w + 1, unk_link.unk + 1, unk, ch_i)
        push!(dix_ptrs, DixPtr(i, 1, false))
        j = 1        
        while j <= length(dix_ptrs)
            dix_ptr::DixPtr = dix_ptrs[j]
            offset = i - dix_ptr.s + 1
            child = lookup(dix, dix_ptr.row_no, offset, ch)
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
                     new_link = Link(dix_ptr.s, dix_link.w + 1, dix_link.unk, dict, ch_i)
                     if isbetter(new_link, link)
                         link = new_link
                     end
                end
            end
        end
        for transducer in transducers
            update(transducer, ch, i, s)
            if transducer.state == completed
                prev_link = path[transducer.s]
                new_link = Link(transducer.s, prev_link.w + 1, prev_link.unk, transducer.link_kind, ch_i)
                if isbetter(new_link, link)
                    link = new_link
                end
            end
        end
        push!(path, link)
        i += 1
    end
    return path
end


struct Range
    s::Int64
    e::Int64
    ch_s::Int64
    ch_e::Int64
end

function path_to_ranges(path::Array{Link}, str::String)::Array{Range}
    if length(path) < 2
        return []
    end
    e = length(path)
    ranges = []
    while e > 1
        link = path[e]
        s = link.p
        p_link = path[s]
        r = Range(s, e, nextind(str, p_link.ch_i), link.ch_i)
        push!(ranges, r)
        e = s
    end
    reverse!(ranges)
    return ranges
end

function range_to_tok(range::Range, str::String)::String
    return SubString(str, range.ch_s, range.ch_e) 
end

function ranges_to_toks(ranges::Array{Range}, str::String)::Array{String}
    return map(r -> range_to_tok(r, str), ranges)
end

function tokenize(dix::PrefixTree{Int32}, str::String)::Array{String}
    path = build_path(dix, str)
    ranges = path_to_ranges(path, str)
    return ranges_to_toks(ranges, str)
end

#dix1 = Wordcut.make_prefix_tree([("กา", Int32(10)), ("กาม", Int32(20))])
#s1 = "กากา"
#println(tokenize(dix1, s1))
end # module
