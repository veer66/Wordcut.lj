using Test

@testset "Wordcut.lj" begin
    tree = Wordcut.make_prefix_tree([("A", 10)])
    @test Wordcut.lookup(tree, 1, 1, 'A') == Wordcut.NodePtr{Int64}(1, true, 10)
    @test isnothing(Wordcut.lookup(tree, 1, 1, 'B'))
    
    tree = Wordcut.make_prefix_tree([("AB", 20)])
    @test Wordcut.lookup(tree, 1, 1, 'A') == Wordcut.NodePtr{Int64}(1, false, nothing)
    @test Wordcut.lookup(tree, 1, 2, 'B') == Wordcut.NodePtr{Int64}(1, true, 20)
    
    tree = Wordcut.make_prefix_tree([("ก", 10), ("กข", 20)])
    @test Wordcut.lookup(tree, 1, 1, 'ก') == Wordcut.NodePtr{Int64}(1, true, 10)
    @test Wordcut.lookup(tree, 1, 2, 'ข') == Wordcut.NodePtr{Int64}(2, true, 20)
end
