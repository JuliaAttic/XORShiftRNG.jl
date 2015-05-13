module XORShift

import Base: rand, rand!

type XORShiftStar1024 <: AbstractRNG
    x00::UInt64
    x01::UInt64
    x02::UInt64
    x03::UInt64
    x04::UInt64
    x05::UInt64
    x06::UInt64
    x07::UInt64
    x08::UInt64
    x09::UInt64
    x10::UInt64
    x11::UInt64
    x12::UInt64
    x13::UInt64
    x14::UInt64
    x15::UInt64
    p::UInt64
end
XORShiftStar() = XORShiftStar1024(rand(UInt64, 16)..., 0)

const globalXORShiftStar1024 = XORShiftStar()

fromUInt64(::Type{UInt64}, u::UInt64) = u
fromUInt64(::Type{Float64}, u::UInt64) = 5.421010862427522e-20 * u

function rand(rng::XORShiftStar1024, ::Type{UInt64})
    @inbounds begin
        p  = rng.p
        s0 = getfield(rng, reinterpret(Int, p)+1)
        p = (p + 1) % 16
        s1 = getfield(rng, reinterpret(Int, p)+1)
        s1 $= s1 << 31
        s1 $= s1 >> 11
        s0 $= s0 >> 30
        s0 $= s1
        unsafe_store!(convert(Ptr{UInt64}, pointer_from_objref(rng))+8,
                      s0, reinterpret(Int, p)+1)
        rng.p = p
    end
    return s0 * 1181783497276652981
end

rand{T<:Number}(rng::XORShiftStar1024, ::Type{T}) = fromUInt64(T, rand(rng, UInt64))

@eval function rand!{T}(rng::XORShiftStar1024, a::AbstractArray{T})
    p = rng.p
    n = length(a)
    q = min((16 - p) % 16, n)
    r = (n - q) % 16
    @inbounds for i = 1:q
        a[i] = rand(rng, T)
    end
    $(Expr(:block, [
        let x = symbol(@sprintf("x%02d", k % 16))
            :($x = rng.$x)
        end
    for k = 0:15 ]...))
    r = q + (n-q) >> 4 << 4
    @inbounds for i = q+1:16:r
        $(Expr(:block, [
            let x0 = symbol(@sprintf("x%02d", k % 16)),
                x1 = symbol(@sprintf("x%02d", (k + 1) % 16))
                quote
                    s0 = $x0
                    s1 = $x1
                    s1 $= s1 << 31
                    s1 $= s1 >> 11
                    s0 $= s0 >> 30
                    s0 $= s1
                    $x1 = s0
                    a[i + $k] = fromUInt64(T, s0 * 1181783497276652981)
                end
            end
        for k = 0:15 ]...))
    end
    $(Expr(:block, [
        let x = symbol(@sprintf("x%02d", k % 16))
            :(rng.$x = $x)
        end
    for k = 0:15 ]...))
    rng.p = 0
    @inbounds for i = r+1:n
        a[i] = rand(rng, T)
    end
    return a
end

end # module
