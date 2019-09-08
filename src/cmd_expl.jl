using SQLite
using Dates
using TimeZones
using Unicode
using StringEncodings

const MAX_UTF16_LENGTH_ITEM = 50
const MAX_UTF16_LENGTH_EXPL = 200
const MAX_EXPL_COUNT = 50

_expl_db_initialized = false

# get the SQLite database, creating/updating it if required
function _expl_db()::SQLite.DB
    db = SQLite.DB(settings.expl_sqlite_file)

    # perform idempotent (!) database initialization once per execution
    global _expl_db_initialized
    if !_expl_db_initialized
        # id must be AUTOINCREMENT because monotonicity is required for some queries
        # nick is NULL for some old entries
        # datetime (unix timestamp) is NULL for some old entries
        # item_norm is a normalized variant of item
        SQLite.execute!(db, """
            CREATE TABLE IF NOT EXISTS t_expl (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nick TEXT,
                item TEXT NOT NULL,
                item_norm TEXT NOT NULL,
                expl TEXT NOT NULL,
                datetime INTEGER,
                enabled INTEGER NOT NULL
            )
            """)

        SQLite.createindex!(db, "t_expl", "idx_expl_item_norm", "item_norm", unique = false, ifnotexists = true)

        _expl_db_initialized = true
    end

    return db
end

# normalize a string (expl item) for easy searchability
_expl_item_normalize(item) = Unicode.normalize(item,
    compat = true,
    casefold = true,
    stripignore = true,
    stripcc = true,
    stable = true)

# number of 16-bit words in the UTF-16 encoding of the given string
# string(s) is required because StringEncodings doesn't support SubString
_utf16_length(s) = length(encode(string(s), enc"UTF-16BE")) >> 1

function add(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    parts = split(rstrip(req.text), limit = 3)
    if length(parts) !== 3
        return OutgoingWebhookResponse("Syntax: $(parts[1]) <Begriff> <Erklärung>")
    end
    _, item, expl = parts

    if _utf16_length(item) > MAX_UTF16_LENGTH_ITEM
        return OutgoingWebhookResponse("Tut mir leid, der Begriff ist leider zu lang.")
    end
    if _utf16_length(expl) > MAX_UTF16_LENGTH_EXPL
        return OutgoingWebhookResponse("Tut mir leid, die Erklärung ist leider zu lang.")
    end

    item_norm = _expl_item_normalize(item)

    db = _expl_db()

    SQLite.Query(db, "INSERT INTO t_expl(nick, item, item_norm, expl, datetime, enabled) VALUES (:nick, :item, :item_norm, :expl, :datetime, :enabled)",
        values = Dict{Symbol, Any}([
            :nick => req.user_name,
            :item => item,
            :item_norm => item_norm,
            :expl => expl,
            :datetime => Dates.datetime2epochms(Dates.now(Dates.UTC)),
            :enabled => 1
        ]))

    permanent_index = normal_index = 1
    for nt in SQLite.Query(db, "SELECT enabled, count(1) FROM t_expl WHERE item_norm = :item_norm AND id < (SELECT id FROM t_expl WHERE rowid = last_insert_rowid()) GROUP BY 1",
        values = Dict{Symbol, Any}([
            :item_norm => item_norm,
        ]))
        permanent_index = permanent_index + nt[2]
        if nt[1] != 0
            normal_index = normal_index + nt[2]
        end
    end

    return OutgoingWebhookResponse("Ich habe den neuen Eintrag mit Index $normal_index hinzugefügt.")
end

abstract type ExplIndex{T<:Unsigned} end

struct NormalExplIndex{T} <: ExplIndex{T}
    index::T
end

struct TailExplIndex{T} <: ExplIndex{T}
    index::T
end

struct PermanentExplIndex{T} <: ExplIndex{T}
    index::T
end

# define strict partial order on ExplIndex subtypes
Base.:<(a::NormalExplIndex, b::NormalExplIndex) = a.index < b.index
Base.:<(a::TailExplIndex, b::TailExplIndex) = a.index > b.index # tail index is descending
Base.:<(a::PermanentExplIndex, b::PermanentExplIndex) = a.index < b.index
Base.:<(::ExplIndex, ::ExplIndex) = false # fallback for unrelated index types

# allows using a single ExplIndex (or subtype) with broadcasting
Base.length(::ExplIndex) = 1
Base.iterate(i::ExplIndex) = (i, nothing)
Base.iterate(::ExplIndex, ::Nothing) = nothing

abstract type ExplIndexSelector{T} end

struct SingleExplIndexSelector{T} <: ExplIndexSelector{T}
    index::ExplIndex{T}
end

struct RangeExplIndexSelector{T} <: ExplIndexSelector{T}
    start::ExplIndex{T}
    stop::ExplIndex{T}
end

struct AllExplIndexSelector{T} <: ExplIndexSelector{T}
end

function Base.tryparse(::Type{NormalExplIndex{T}}, s::AbstractString) where {T}
    index = tryparse(T, s)
    if isnothing(index) || index == 0
        return nothing
    end
    return NormalExplIndex{T}(index)
end

function Base.tryparse(::Type{TailExplIndex{T}}, s::AbstractString) where {T}
    if !startswith(s, '-')
        return nothing
    end
    index = tryparse(T, s[2:end])
    if isnothing(index) || index == 0
        return nothing
    end
    return TailExplIndex{T}(index)
end

function Base.tryparse(::Type{PermanentExplIndex{T}}, s::AbstractString) where {T}
    if !startswith(s, 'p')
        return nothing
    end
    index = tryparse(T, s[2:end])
    if isnothing(index) || index == 0
        return nothing
    end
    return PermanentExplIndex{T}(index)
end

function Base.tryparse(::Type{ExplIndex{T}}, s::AbstractString) where {T}
    for t in [NormalExplIndex{T}, TailExplIndex{T}, PermanentExplIndex{T}]
        i = tryparse(t, s)
        if !isnothing(i)
            return i
        end
    end
    return nothing
end

function Base.tryparse(::Type{ExplIndexSelector{T}}, s::AbstractString) where {T}
    p = split(s, ':', limit = 3)
    if length(p) > 2
        return nothing
    end

    start = tryparse(ExplIndex{T}, p[1])
    if isnothing(start)
        return nothing
    end

    if length(p) == 1
        return SingleExplIndexSelector{T}(start)
    end

    stop = tryparse(ExplIndex{T}, p[2])
    if isnothing(stop)
        return nothing
    end

    return RangeExplIndexSelector{T}(start, stop)
end

struct ExplEntry{T}
    text::AbstractString
    indexes::Vector{ExplIndex{T}}
end

# allows using a single ExplEntry with broadcasting
Base.length(::ExplEntry) = 1
Base.iterate(i::ExplEntry) = (i, nothing)
Base.iterate(::ExplEntry, ::Nothing) = nothing

# checks if an ExplIndexSelector selects an ExplEntry
selects(s::SingleExplIndexSelector{T}, e::ExplEntry{T}) where {T} = any(s.index .== e.indexes)
selects(s::RangeExplIndexSelector{T}, e::ExplEntry{T}) where {T} = any(s.start .<= e.indexes) && any(e.indexes .<= s.stop)
selects(::AllExplIndexSelector{T}, ::ExplEntry{T}) where {T} = true

function expl(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    parts = split(req.text)
    selectors = tryparse.(ExplIndexSelector{UInt64}, parts[3:end])
    if length(parts) < 2 || any(selectors .== nothing)
        return OutgoingWebhookResponse("Syntax: $(parts[1]) <Begriff> { <Index> | <VonIndex>:<BisIndex> }")
    end

    # default range (all)
    if isempty(selectors)
        selectors = [AllExplIndexSelector{UInt64}()]
    end

    item = parts[2]
    item_norm = _expl_item_normalize(item)

    db = _expl_db()

    entries = []
    permanent_index = normal_index = UInt64(1)
    for nt in SQLite.Query(db, "SELECT nick, item, expl, datetime, enabled FROM t_expl WHERE item_norm = :item_norm ORDER BY id",
        values = Dict{Symbol, Any}([
            :item_norm => item_norm,
        ]))

        if nt.:enabled != 0
            text = "$(nt.item)[$normal_index]: " * replace(nt.:expl, r"[[:space:]]" => " ")
            metadata = []
            if !ismissing(nt.:nick)
                push!(metadata, nt.:nick)
            end
            if !ismissing(nt.:datetime)
                datetime = Dates.format(ZonedDateTime(Dates.epochms2datetime(nt.:datetime), settings.expl_time_zone, from_utc = true), settings.expl_datetime_format)
                push!(metadata, datetime)
            end
            if !isempty(metadata)
                text = "$text (" * join(metadata, ", ") * ')'
            end

            indexes = [NormalExplIndex(normal_index), PermanentExplIndex(permanent_index)]

            push!(entries, ExplEntry(text, indexes))

            normal_index = normal_index + 1
        end

        permanent_index = permanent_index + 1
    end

    # determine tail indexes
    tail_index = UInt64(length(entries))
    for entry in entries
        push!(entry.indexes, TailExplIndex(tail_index))
        tail_index = tail_index - 1
    end

    # apply selectors
    selected = filter(entry -> any(selects.(selectors, entry)), entries)

    count = length(selected)
    if count == 0
        text = "Ich habe leider keinen Eintrag gefunden."
    else
        if count == 1
            text = "Ich habe den folgenden Eintrag gefunden:"
        elseif count <= MAX_EXPL_COUNT
            text = "Ich habe die folgenden $count Einträge gefunden:"
        else
            text = "Ich habe $count Einträge gefunden, das sind die letzten $MAX_EXPL_COUNT:"
            selected = selected[end-MAX_EXPL_COUNT+1:end]
        end

        text = "$text\n```\n" * join(map(entry -> entry.text, selected), '\n') * "\n```"
    end

    title = join(parts, ' ')
    fallback = "Es tut mir leid, dein Client kann die Ergebnisse von $(parts[1]) leider nicht anzeigen."

    return OutgoingWebhookResponse([MessageAttachment(fallback, title, text)])
end
