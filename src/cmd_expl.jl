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
        return OutgoingWebhookResponse("Syntax: !add <Begriff> <Erklärung>")
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

    local count
    for nt in SQLite.Query(db, "SELECT count(1) cnt FROM t_expl WHERE item_norm = :item_norm AND id <= (SELECT id FROM t_expl WHERE rowid = last_insert_rowid())",
        values = Dict{Symbol, Any}([
            :item_norm => item_norm,
        ]))
        count = nt[1]
    end

    return OutgoingWebhookResponse("Ich habe den neuen Eintrag " * item * "[" * string(count) * "] hinzugefügt.")
end

function expl(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    parts = split(rstrip(req.text), limit = 3)
    if length(parts) !== 2
        return OutgoingWebhookResponse("Syntax: !expl <Begriff>")
    end
    _, item = parts
    item_norm = _expl_item_normalize(item)

    db = _expl_db()

    entries = []
    index = 0
    for nt in SQLite.Query(db, "SELECT nick, item, expl, datetime, enabled FROM t_expl WHERE item_norm = :item_norm ORDER BY id",
        values = Dict{Symbol, Any}([
            :item_norm => item_norm,
        ]))

        index = index + 1

        if nt.:enabled != 0
            entry = nt.:item * "[" * string(index) * "]: " * replace(nt.:expl, r"[[:space:]]" => " ")
            extra = []
            if !ismissing(nt.:nick)
                push!(extra, nt.:nick)
            end
            if !ismissing(nt.:datetime)
                datetime = Dates.format(ZonedDateTime(Dates.epochms2datetime(nt.:datetime), settings.expl_time_zone, from_utc = true), settings.expl_datetime_format)
                push!(extra, datetime)
            end
            if !isempty(extra)
                entry = entry * " (" * join(extra, ", ") * ")"
            end

            push!(entries, entry)
        end
    end

    count = length(entries)
    if count == 0
        text = "Ich habe leider keinen Eintrag gefunden."
    else
        if count == 1
            text = "Ich habe den folgenden Eintrag gefunden:"
        elseif count <= MAX_EXPL_COUNT
            text = "Ich habe die folgenden " * string(count) * " Einträge gefunden:"
        else
            text = "Ich habe " * string(count) * " Einträge gefunden, das sind die letzten " * string(MAX_EXPL_COUNT) * ":"
            entries = entries[end-MAX_EXPL_COUNT+1:end]
        end
        text = text * "\n```\n" * join(entries, '\n') * "\n```"
    end

    title = "!expl " * item
    fallback = "Es tut mir leid, dein Client kann die Ergebnisse von !expl leider nicht anzeigen."

    return OutgoingWebhookResponse([MessageAttachment(fallback, title, text)])
end
