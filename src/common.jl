
# print arrays in pretty way

function printarr(io::IO, a::AbstractArray)
    Base.with_output_limit(()->Base.showarray(io, a, header=false, repr=false))
end

printvec(io::IO, a::AbstractVector) = printarr(io, a')

printarrln(io::IO, a::AbstractArray) = (printarr(io, a); println(io))
printvecln(io::IO, a::AbstractVector) = (printvec(io, a); println(io))

# centralize

centralize(x::AbstractVector, m::AbstractVector) = (isempty(m) ? x : x - m)
centralize(x::AbstractMatrix, m::AbstractVector) = (isempty(m) ? x : x .- m)

decentralize(x::AbstractVector, m::AbstractVector) = (isempty(m) ? x : x + m)
decentralize(x::AbstractMatrix, m::AbstractVector) = (isempty(m) ? x : x .+ m)

# get a full mean vector

fullmean(d::Int, mv::AbstractVector{T}) where T = (isempty(mv) ? zeros(T, d) : mv)

preprocess_mean(X::AbstractMatrix{T}, m; dims=2) where T<:Real =
    (m === nothing ? vec(mean(X, dims=dims)) : m == 0 ? T[] :  m)

# choose the first k values and columns
#
# S must have fields: values & vectors

function extract_kv(fac::Factorization{T}, ord::AbstractVector{Int}, k::Int) where T
    si = ord[1:k]
    vals = fac.values[si]::Vector{T}
    vecs = fac.vectors[:, si]::Matrix{T}
    return (vals, vecs)
end


# symmmetrize a matrix

function symmetrize!(A::Matrix)
    n = size(A, 1)
    @assert size(A, 2) == n
    for j = 1:n
        for i = 1:j-1
            @inbounds A[i,j] = A[j,i]
        end
        for i = j+1:n
            @inbounds A[i,j] = (A[i,j] + A[j,i])/2
        end
    end
    return A
end

# percolumn dot

function coldot(X::AbstractMatrix{T}, Y::AbstractMatrix{T}) where T<:Real
    m = size(X, 1)
    n = size(X, 2)
    @assert size(Y) == (m, n)
    R = zeros(T, n)
    for j = 1:n
        R[j] = dot(view(X,:,j), view(Y,:,j))
    end
    return R
end

# qnormalize!

function qnormalize!(X, C)
    # normalize each column of X (say x), such that x'Cx = 1
    m = size(X, 1)
    n = size(X, 2)
    CX = C * X
    for j = 1:n
        x = view(X,:,j)
        cx = view(CX,:,j)
        rmul!(x, inv(sqrt(dot(x, cx))))
    end
    return X
end

# add_diag!

function add_diag!(A::AbstractMatrix, v::Real)
    # add v to diagonal of A
    m = size(A, 1)
    n = size(A, 2)
    @assert m == n
    if v != zero(v)
        for i = 1:n
            @inbounds A[i,i] += v
        end
    end
    return A
end

# regularize a symmetric matrix
function regularize_symmat!(A::AbstractMatrix{T}, lambda::Real) where T<:Real
    if lambda > 0
        emax = eigmax(Symmetric(A))
        add_diag!(A, emax * lambda)
    end
    return A
end

"""
    calcscattermat([covestimator::CovarianceEstimator], Z::DenseMatrix)

Calculate the scatter matrix of centered data `Z` based on a covariance
matrix calculated using covariance estimator `covestimator` (by default,
`SimpleCovariance()`).
"""
function calcscattermat(covestimator::CovarianceEstimator, Z::DenseMatrix{T}) where T<:Real
    return cov(covestimator, Z; dims=2, mean=zeros(T, size(Z, 1)))*size(Z, 2)
end

function calcscattermat(Z::DenseMatrix)
    return calcscattermat(SimpleCovariance(), Z)
end


# distance
"""
    L2distance(X)

Calculate a symmetric Euclidean (L2) distance matrix.
"""
L2distance(X::AbstractMatrix{T}) where {T<:Real} = L2distance!(zeros(T,size(X,2),size(X,2)), X)
L2distance!(D::AbstractMatrix, X::AbstractMatrix) =
    pairwise!((x,y)->norm(x-y), D, eachcol(X), symmetric=true)

