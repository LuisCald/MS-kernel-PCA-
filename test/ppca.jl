using MultivariateStats
using LinearAlgebra
using Test
using StableRNGs
import Statistics: mean, cov, var
import SparseArrays
import StatsBase

@testset "Probabilistic PCA" begin

    rng = StableRNG(34568)

    ## PCA with zero mean

    X = randn(rng, 5, 10)
    Y = randn(rng, 3, 10)

    W = qr(randn(rng, 5, 5)).Q[:, 1:3]
    σ² = 0.1
    M = PPCA(Float64[], W, σ²)

    @test size(M) == (5,3)
    @test mean(M) == zeros(5)
    @test loadings(M) == W
    @test var(M) == σ²

    T = inv(W'*W .+ σ²*Matrix(I, 3, 3))*W'
    @test predict(M, X[:,1]) ≈ T * X[:,1]
    @test predict(M, X) ≈ T * X

    R = W*inv(W'W)*(W'W .+ σ²*Matrix(I, 3, 3))
    @test reconstruct(M, Y[:,1]) ≈ R * Y[:,1]
    @test reconstruct(M, Y) ≈ R * Y


    ## PCA with non-zero mean

    mval = rand(rng, 5)
    M = PPCA(mval, W, σ²)

    @test size(M) == (5,3)
    @test mean(M) == mval
    @test loadings(M) == W
    @test var(M) == σ²

    @test predict(M, X[:,1]) ≈ T * (X[:,1] .- mval)
    @test predict(M, X) ≈ T * (X .- mval)

    @test reconstruct(M, Y[:,1]) ≈ R * Y[:,1] .+ mval
    @test reconstruct(M, Y) ≈ R * Y .+ mval


    ## prepare training data

    d = 5
    n = 1000

    R = collect(qr(randn(rng, d, d)).Q)
    @test R'R ≈ Matrix(I, 5, 5)
    rmul!(R, Diagonal(sqrt.([0.5, 0.3, 0.1, 0.05, 0.05])))

    X = R'randn(rng, 5, n) .+ randn(rng, 5)
    mval = vec(mean(X, dims=2))
    Z = X .- mval

    M0 = fit(PCA, X; mean=mval, maxoutdim = 4)

    ## ppcaml (default)

    M = fit(PPCA, X)
    P = projection(M)
    W = loadings(M)

    @test size(M) == (5,4)
    @test mean(M) == mval
    @test P'P ≈ Matrix(I, 4, 4)
    @test reconstruct(M, predict(M, X)) ≈ reconstruct(M0, predict(M0, X))

    M = fit(PPCA, X; mean=mval)
    @test loadings(M) ≈ W

    M = fit(PPCA, Z; mean=0)
    @test loadings(M) ≈ W

    M = fit(PPCA, X; maxoutdim=3)
    P = projection(M)
    W = loadings(M)

    @test size(M) == (5,3)
    @test P'P ≈ Matrix(I, 3, 3)

    # ppcaem

    M = fit(PPCA, X; method=:em)
    P = projection(M)
    W = loadings(M)

    @test size(M) == (5,4)
    @test mean(M) == mval
    @test P'P ≈ Matrix(I, 4, 4)
    @test all(isapprox.(reconstruct(M, predict(M, X)), reconstruct(M0, predict(M0, X)), atol=1e-2))

    M = fit(PPCA, X; method=:em, mean=mval)
    @test loadings(M) ≈ W

    M = fit(PPCA, Z; method=:em, mean=0)
    @test loadings(M) ≈ W

    M = fit(PPCA, X; method=:em, maxoutdim=3)
    P = projection(M)

    @test size(M) == (5,3)
    @test P'P ≈ Matrix(I, 3, 3)

    @test_throws StatsBase.ConvergenceException fit(PPCA, X; method=:em, maxiter=1)

    # bayespca
    M0 = fit(PCA, X; mean=mval, maxoutdim = 3)

    M = fit(PPCA, X; method=:bayes)
    P = projection(M)
    W = loadings(M)

    @test size(M) == (5,3)
    @test mean(M) == mval
    @test P'P ≈ Matrix(I, 3, 3)
    @test reconstruct(M, predict(M, X)) ≈ reconstruct(M0, predict(M0, X))

    M = fit(PPCA, X; method=:bayes, mean=mval)
    @test loadings(M) ≈ W

    M = fit(PPCA, Z; method=:bayes, mean=0)
    @test loadings(M) ≈ W

    M = fit(PPCA, X; method=:em, maxoutdim=2)
    P = projection(M)

    @test size(M) == (5,2)
    @test P'P ≈ Matrix(I, 2, 2)

    @test_throws StatsBase.ConvergenceException fit(PPCA, X; method=:bayes, maxiter=1)

    # Different data types
    # --------------------
    X = randn(rng, Float64, 5, 10)
    XX = convert.(Float32, X)

    Y = randn(rng, Float64, 1, 10)
    YY = convert.(Float32, Y)

    for method in (:bayes, :em)
        M = fit(PPCA, X ; maxoutdim=1, method=method)
        MM = fit(PPCA, XX ; maxoutdim=1, method=method)

        # mix types
        predict(M, XX)
        predict(MM, X)
        reconstruct(M, YY)
        reconstruct(MM, Y)

        # type consistency
        for func in (mean, projection, var, loadings)
            @test eltype(func(M)) == Float64
            @test eltype(func(MM)) == Float32
        end
    end

    # views
    X = randn(rng, 5, 200)
    M = fit(PPCA, view(X, :, 1:100), maxoutdim=3)
    M = fit(PPCA, view(X, :, 1:100), maxoutdim=3, method=:em)
    M = fit(PPCA, view(X, :, 1:100), maxoutdim=3, method=:bayes)
    # sparse
    @test_throws AssertionError fit(PPCA, SparseArrays.sprandn(rng, 100d, n, 0.6))

end
