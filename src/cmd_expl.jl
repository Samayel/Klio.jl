module Expl

using SQLite
using Dates
using TimeZones
using Unicode
using StringEncodings

using ...Klio
using ..Mattermost

const MAX_UTF16_LENGTH_ITEM = 50
const MAX_UTF16_LENGTH_EXPL = 200
const MAX_EXPL_COUNT = 50

db_initialized = false

# get the SQLite database, creating/updating it if required
function init_db()::SQLite.DB
    db = SQLite.DB(Klio.settings.expl_sqlite_file)

    # perform idempotent (!) database initialization once per execution
    global db_initialized
    if !db_initialized
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

        db_initialized = true
    end

    return db
end

# common query to determine the different indexes
# returns all entries (including disabled ones) unordered
const QUERY_BY_ITEM_NORM = """
	SELECT rowid, id, nick, item, item_norm, expl, datetime, enabled,
		   CASE WHEN enabled <> 0 THEN ROW_NUMBER() OVER (PARTITION BY enabled <> 0 ORDER BY id) END normal_index,
		   ROW_NUMBER() OVER (ORDER BY id) permanent_index,
           CASE WHEN enabled <> 0 THEN ROW_NUMBER() OVER (PARTITION BY enabled <> 0 ORDER BY id DESC) END tail_index
	FROM t_expl WHERE item_norm = :item_norm
"""

const QUERY_BY_ITEM_NORM_PARAM = :item_norm

# normalize a string (expl item) for easy searchability
item_normalize(item) = Unicode.normalize(item,
    compat = true,
    casefold = true,
    stripignore = true,
    stripcc = true,
    stable = true)

# number of 16-bit words in the UTF-16 encoding of the given string
# string(s) is required because StringEncodings doesn't support SubString
utf16_length(s) = length(encode(string(s), enc"UTF-16BE")) >> 1

function add(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    parts = split(rstrip(req.text), limit = 3)
    if length(parts) !== 3
        return OutgoingWebhookResponse("Syntax: $(parts[1]) <Begriff> <Erklärung>")
    end
    _, item, expl = parts

    if utf16_length(item) > MAX_UTF16_LENGTH_ITEM
        return OutgoingWebhookResponse("Tut mir leid, der Begriff ist leider zu lang.")
    end
    if utf16_length(expl) > MAX_UTF16_LENGTH_EXPL
        return OutgoingWebhookResponse("Tut mir leid, die Erklärung ist leider zu lang.")
    end

    item_norm = item_normalize(item)

    db = init_db()

    SQLite.Query(db, "INSERT INTO t_expl(nick, item, item_norm, expl, datetime, enabled) VALUES (:nick, :item, :item_norm, :expl, :datetime, :enabled)",
        values = Dict{Symbol, Any}([
            :nick => req.user_name,
            :item => item,
            :item_norm => item_norm,
            :expl => expl,
            :datetime => Dates.datetime2epochms(Dates.now(Dates.UTC)),
            :enabled => 1
        ]))

    permanent_index = normal_index = 0
    for nt in SQLite.Query(db, "SELECT normal_index, permanent_index FROM ($QUERY_BY_ITEM_NORM) WHERE rowid = last_insert_rowid()",
        values = Dict{Symbol, Any}([
            QUERY_BY_ITEM_NORM_PARAM => item_norm,
        ]))
        normal_index = nt.:normal_index
        permanent_index = nt.:permanent_index
    end

    return OutgoingWebhookResponse("Ich habe den neuen Eintrag mit Index $normal_index/p$permanent_index hinzugefügt.")
end

abstract type ExplIndex end

struct NormalExplIndex <: ExplIndex
    index::Int64
end

struct TailExplIndex <: ExplIndex
    index::Int64
end

struct PermanentExplIndex <: ExplIndex
    index::Int64
end

# string representation, used by join and string interpolation
Base.print(io::IO, x::NormalExplIndex) = print(io, string(x.index))
Base.print(io::IO, x::PermanentExplIndex) = print(io, 'p', string(x.index))
Base.print(io::IO, x::TailExplIndex) = print(io, '-', string(x.index))

# define strict partial order on ExplIndex subtypes
Base.:<(a::NormalExplIndex, b::NormalExplIndex) = a.index < b.index
Base.:<(a::TailExplIndex, b::TailExplIndex) = a.index > b.index # tail index is descending
Base.:<(a::PermanentExplIndex, b::PermanentExplIndex) = a.index < b.index
Base.:<(::ExplIndex, ::ExplIndex) = false # fallback for unrelated index types

# allows using a single ExplIndex (or subtype) with broadcasting
Base.length(::ExplIndex) = 1
Base.iterate(i::ExplIndex) = (i, nothing)
Base.iterate(::ExplIndex, ::Nothing) = nothing

abstract type ExplIndexSelector end

struct SingleExplIndexSelector <: ExplIndexSelector
    index::ExplIndex
end

struct RangeExplIndexSelector <: ExplIndexSelector
    start::ExplIndex
    stop::ExplIndex
end

struct AllExplIndexSelector <: ExplIndexSelector
end

function Base.tryparse(t::Type{NormalExplIndex}, s::AbstractString)
    index = tryparse(fieldtype(t, :index), s)
    if isnothing(index) || index <= 0
        return nothing
    end
    return NormalExplIndex(index)
end

function Base.tryparse(t::Type{TailExplIndex}, s::AbstractString)
    if !startswith(s, '-')
        return nothing
    end
    index = tryparse(fieldtype(t, :index), s[2:end])
    if isnothing(index) || index <= 0
        return nothing
    end
    return TailExplIndex(index)
end

function Base.tryparse(t::Type{PermanentExplIndex}, s::AbstractString)
    if !startswith(s, 'p')
        return nothing
    end
    index = tryparse(fieldtype(t, :index), s[2:end])
    if isnothing(index) || index <= 0
        return nothing
    end
    return PermanentExplIndex(index)
end

function Base.tryparse(::Type{ExplIndex}, s::AbstractString)
    for t in [NormalExplIndex, TailExplIndex, PermanentExplIndex]
        i = tryparse(t, s)
        if !isnothing(i)
            return i
        end
    end
    return nothing
end

function Base.tryparse(::Type{ExplIndexSelector}, s::AbstractString)
    p = split(s, ':', limit = 3)
    if length(p) > 2
        return nothing
    end

    start = tryparse(ExplIndex, p[1])
    if isnothing(start)
        return nothing
    end

    if length(p) == 1
        return SingleExplIndexSelector(start)
    end

    stop = tryparse(ExplIndex, p[2])
    if isnothing(stop)
        return nothing
    end

    return RangeExplIndexSelector(start, stop)
end

struct ExplEntry
    item::AbstractString
    indexes::Vector{ExplIndex}
    text::AbstractString
end

# string representation, used by join and string interpolation
Base.print(io::IO, e::ExplEntry) = print(io, "$(e.item)[" * join(e.indexes, '/') * "]: $(e.text)")

# allows using a single ExplEntry with broadcasting
Base.length(::ExplEntry) = 1
Base.iterate(i::ExplEntry) = (i, nothing)
Base.iterate(::ExplEntry, ::Nothing) = nothing

# checks if an ExplIndexSelector selects an ExplEntry
selects(s::SingleExplIndexSelector, e::ExplEntry) = any(s.index .== e.indexes)
selects(s::RangeExplIndexSelector, e::ExplEntry) = any(s.start .<= e.indexes) && any(e.indexes .<= s.stop)
selects(::AllExplIndexSelector, ::ExplEntry) = true

# unique ExplIndex subtypes used by an ExplIndexSelector
indextypes(s::SingleExplIndexSelector) = [typeof(s.index)]
indextypes(s::RangeExplIndexSelector) = unique([typeof(s.start), typeof(s.stop)])
indextypes(s::AllExplIndexSelector) = [NormalExplIndex]

function expl(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    parts = split(req.text)
    selectors = tryparse.(ExplIndexSelector, parts[3:end])
    if length(parts) < 2 || any(selectors .== nothing)
        return OutgoingWebhookResponse("Syntax: $(parts[1]) <Begriff> { <Index> | <VonIndex>:<BisIndex> }")
    end

    # default range (all)
    if isempty(selectors)
        selectors = [AllExplIndexSelector()]
    end

    # determine index types used in selectors
    index_types = union(map(indextypes, selectors)...)
    use_normal_index = NormalExplIndex in index_types
    use_permanent_index = PermanentExplIndex in index_types
    use_tail_index = TailExplIndex in index_types

    # show normal index if no others are shown
    if !use_permanent_index && !use_tail_index
        use_normal_index = true
    end

    item = parts[2]
    item_norm = item_normalize(item)

    db = init_db()

    entries = []
    for nt in SQLite.Query(db, "SELECT * FROM ($QUERY_BY_ITEM_NORM) WHERE enabled <> 0 ORDER BY id",
        values = Dict{Symbol, Any}([
            QUERY_BY_ITEM_NORM_PARAM => item_norm,
        ]))

        text = replace(nt.:expl, r"[[:space:]]" => " ")

        metadata = []
        if !ismissing(nt.:nick)
            push!(metadata, nt.:nick)
        end
        if !ismissing(nt.:datetime)
            datetime = Dates.format(ZonedDateTime(Dates.epochms2datetime(nt.:datetime), Klio.settings.expl_time_zone, from_utc = true), Klio.settings.expl_datetime_format)
            push!(metadata, datetime)
        end
        if !isempty(metadata)
            text = "$text (" * join(metadata, ", ") * ')'
        end

        indexes = Vector{ExplIndex}()
        if use_normal_index
            push!(indexes, NormalExplIndex(nt.:normal_index))
        end
        if use_permanent_index
            push!(indexes, PermanentExplIndex(nt.:permanent_index))
        end
        if use_tail_index
            push!(indexes, TailExplIndex(nt.:tail_index))
        end

        push!(entries, ExplEntry(nt.:item, indexes, text))
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

        text = "$text\n```\n" * join(selected, '\n') * "\n```"
    end

    return OutgoingWebhookResponse(text)
end

end
