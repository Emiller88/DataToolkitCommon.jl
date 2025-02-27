# Without context

function Base.hash(dataset::DataSet, h::UInt)
    for field in (:uuid, :parameters, :storage, :loaders, :writers)
        h = hash(getfield(dataset, field), h)
    end
    h
end

function Base.hash(adt::AbstractDataTransformer, h::UInt)
    suphash = xor(hash.(adt.type)...)
    driver = first(typeof(adt).parameters)
    h = hash(suphash, h)
    h = hash(adt.priority, h)
    h = hash(adt.parameters, h)
    h = hash(driver, h)
end

function Base.hash(ident::Identifier, h::UInt)
    for field in fieldnames(Identifier)
        h = hash(getfield(ident, field), h)
    end
    h
end

# With context

if VERSION < v"1.7"
    @warn string("Contextual hashes made with Julia <1.7 will not be consistent ",
                 "with hashes constructed in Julia 1.7+.\n",
                 "This is due to a change in the definition of hash(Symbol, UInt).\n",
                 "Expect unnecessary cache invalidations if moving between Julia <1.7 and 1.7+.")
end

Base.hash((collection, obj)::Tuple{DataCollection, <:Any}, h::UInt) =
    chash(collection, obj, h)

"""
    chash(collection::DataCollection, obj, h::UInt)
    chash(obj::DataSet, h::UInt=0)                 # Convenience form
    chash(obj::AbstractDataTransformer, h::UInt=0) # Convenience form
Generate a hash of `obj` with respect to its `collection` context, which should
be *consistent* across sessions and cosmetic changes (chash = consistent hash).

This function has a catch-all method that falls back to calling `hash`, with
special implementations for the following `obj` types:
- `DataSet`
- `AbstractDataTransformer`
- `Identifier`
- `Dict`
- `Pair`
- `Vector`
"""
function chash end

function chash(c::DataCollection, h::UInt=zero(UInt))
    h = chash(c, c.version, h)
    h = chash(c, c.uuid, h)
    h = reduce(xor, chash.(Ref(c), c.plugins, h))
    h = chash(c, c.parameters, h)
    for ds in c.datasets
        h = chash(c, ds, h)
    end
    # REVIEW Not sure if this should be included
    # h = chash(c, nameof(c.mod), h)
    h
end

chash(ds::DataSet, h::UInt=zero(UInt)) =
    chash(ds.collection, ds, h)

chash(adt::AbstractDataTransformer, h::UInt=zero(UInt)) =
    chash(adt.dataset.collection, adt, h)

function chash(collection::DataCollection, ds::DataSet, h::UInt)
    h = hash(ds.uuid, h)
    for field in (:parameters, :storage, :loaders, :writers)
        h = chash(collection, getfield(ds, field), h)
    end
    h
end

function chash(collection::DataCollection, adtl::Vector{AbstractDataTransformer}, h::UInt)
    reduce(xor, chash.(Ref(collection), adtl, zero(UInt)))
end

function chash(collection::DataCollection, adt::AbstractDataTransformer, h::UInt)
    suphash = reduce(xor, chash.(adt.type))
    driver = first(typeof(adt).parameters)
    h = hash(suphash, h)
    h = hash(adt.priority, h)
    h = chash(collection, adt.parameters, h)
    h = hash(driver, h)
end

function chash(collection::DataCollection, ident::Identifier, h::UInt)
    h = hash(ident.collection, h)
    h = chash(collection, resolve(collection, ident, resolvetype=false), h)
    h = chash(ident.type, h)
    h = chash(collection, ident.parameters, h)
end

function chash(qt::QualifiedType, h::UInt=zero(UInt))
    hash(qt.parentmodule,
         hash(qt.name,
              hash(chash.(qt.parameters), h)))
end

chash(dt::Type, h::UInt=zero(UInt)) =
    chash(QualifiedType(dt), h)

function chash(collection::DataCollection, dict::Dict, h::UInt)
    reduce(xor, [chash(collection, kv, zero(UInt)) for kv in dict],
           init=h)
end

function chash(collection::DataCollection, pair::Pair, h::UInt)
    chash(collection, pair.second, chash(collection, pair.first, h))
end

function chash(collection::DataCollection, vec::Vector, h::UInt)
    for v in vec
        h = chash(collection, v, h)
    end
    h
end

chash(::DataCollection, obj::String, h::UInt) = hash(obj, h)
chash(::DataCollection, obj::Number, h::UInt) = hash(obj, h)
chash(::DataCollection, obj::Symbol, h::UInt) = hash(obj, h)

chash(c::DataCollection, obj::T, h::UInt) where {T} =
    reduce(xor, (chash(c, getfield(obj, f), zero(UInt)) for f in fieldnames(T)),
           init=chash(QualifiedType(T), h))

chash(obj::Any, h::UInt=zero(UInt)) = chash(DataCollection(), obj, h)
