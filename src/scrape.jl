"""
    scrape(url::String)::Gumbo.HTMLElement{:HTML}

Scrapes a URL and returns a Gumbo object

# Arguments
- `url::String`: The target URL

# Returns
- `::Gumbo.HTMLElement{:HTML}`: The HTML body of the GET request

# Examples
```julia
julia> scrape("https://example.com")
Gumbo.HTMLElement{:HTML}:<HTML>
  <head>
    <title>
      Example Domain
    </title>
    <meta charset="utf-8"/>
    <meta content="text/html; charset=utf-8" http-equiv="Content-type"/>
    <meta content="width=device-width, initial-scale=1" name="viewport"/>
    <style type="text/css">
    body {
        background-color: #f0f0f2;
        margin: 0;
        padding: 0;
        font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", "Open Sans", "Helvetica Neue", Helvetica, Arial, sans-serif;

    }
    div {
        width: 600px;
        margin: 5em auto;
        padding: 2em;
...
```
"""
function scrape(url::String)::Gumbo.HTMLElement{:HTML}
    resp = HTTP.get(url)
    root = resp.body |> String |> parsehtml
    return root.root
end


"""
    scrape_speeches(html::Gumbo.HTMLElement{:HTML})::DataFrame

Retrieves all of the SOU speeches and returns them in a DataFrame

# Arguments
- `html::Gumbo.HTMLElement{:HTML}`: The body of the target page as a Gumbo object
- `get_traces::Bool=false`: Return traces with dataframe (optional, default=false)

# Returns
- `speeches::DataFrame`: A DataFrame of the contents of the speeches.
- `failed::Dict`: Dictionary of backtraces for failed scrape attempts.

# Examples
```julia
julia> scrape_speeches(html)
NxM DataFrame
[...]
```
"""
function scrape_speeches(html; get_traces::Bool=false)
    linktable = eachmatch(sel"div.toc", html) |> first
    speeches = []
    failed = Dict()
    lk = ReentrantLock()
    Threads.@threads for link in eachmatch(sel"a", linktable)
        l = first(link.children).text
        @info "Thread $(Threads.threadid())" link.attributes["href"]
        try
            speech = scrape_speech(link)
            isnothing(speech) && continue
            lock(lk) do
                push!(speeches, speech)
            end
            @info "success" l
        catch
            ex = stacktrace(catch_backtrace())
            @error "failed" l
            failed[first(link.children).text] = ex
        end
    end
    df = DataFrame(speeches)
    sort!(df, :date)
    df.id = 1:nrow(df)
    select!(df, [:id, :president, :date, :url, :article_id, :data_history_node_id, :speech])
    get_traces && return (df, failed)
    return df
end


"""
    scrape_speech(link)

Scrapes an SOU speech given a link from the TOC page and returns
a NamedTuple to be a dataframe record.

# Arguments
- `link::Gumbo.HTMLElement{:a}`: Link element from SOU list.

# Returns
-  `::NamedTuple`: A record to be inserted into a dataframe

# Example
```julia
julia> scrape_speech(link)
(president = "George Washington", date = Date("1790-01-08"), [...])
```
"""
function scrape_speech(link)
    # Get president and date from link text
    pd = strip.(split(first(link.children).text, '('))
    length(pd) == 1 && return # Not a complete speech / linked to elsewhere
    president, date = pd

    # Clean up date
    date = clean_date(date)

    resource_path = link.attributes["href"]

    # Check URL, try two othe common alternatives
    url = check_url(String(resource_path), String(president), date)
    if typeof(url) ≠ String
        return url
    end

    # Scrape the Speech from the given resource path
    speech = eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)) |> first
    data_history_node_id = speech.attributes["data-history-node-id"]
    id = missing
    if !isempty(eachmatch(sel"a[id#=(^[a-zA-Z0-9]+$)]", speech))
        id = get(getproperty(first(eachmatch(sel"a[id#=(^[a-zA-Z0-9]+$)]", speech)), :attributes), "id", missing)
    end

    # Multipart Speeches (e.g. Bush 2006)
    toc = eachmatch(sel"div.toc", speech)
    if isempty(toc)
        text = join([strip(first(p.children).text) for p in eachmatch(sel"p", speech)], '\n')
    else
        @info "Multiple sections in Table of Contents located"
        text = []
        for a in eachmatch(sel"a", first(toc))
            a = a.attributes["href"]
            if occursin("#", a)
                push!(text, join([string(p.children |> first) for p in eachmatch(sel"p", speech)], '\n'))
                continue
            end
            url = BASE_PATH * a
            speech_section = eachmatch(sel"div.section", scrape(url)) |> first
            push!(text, join([string(p.children |> first) for p in eachmatch(sel"p", speech_section)], '\n'))
        end
        text = join(text, '\n')
    end

    return (; president=president, date=date, url=url, article_id=id, data_history_node_id=data_history_node_id, speech=text)
end


"""
    scrape_all_to_string(html::Gumbo.HTMLElement{:HTML})

Scrape all speeches and dump to one string.

# Arguments
- `html::Gumbo.HTMLElement{:HTML}`: Parsed HTML object

# Returns
- `::String`: A large string of all the elements from each speech

# Examples
```julia
julia> scrape_all_to_string(html)
String
[...]
```
"""
function scrape_all_to_string(html::Gumbo.HTMLElement{:HTML})::String
    linktable = eachmatch(sel"div.toc", html) |> first
    speeches = []
    lk = ReentrantLock()
    Threads.@threads for link in eachmatch(sel"a", linktable)
        speech = String[]
        lock(lk) do
            push!(speech, string(link))
        end
        pd = strip.(split(first(link.children).text, '('))
        length(pd) ≠ 2 && continue
        resource_path = link.attributes["href"]
        url = BASE_PATH * resource_path
        if isempty(eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)))
            pres, date = pd
            date = clean_date(date)
            url = check_url(resource_path, pres, date)
            if typeof(url) ≠ String
                lock(lk) do
                    push!(speeches, join(speech))
                end
                continue
            end
        end
        speechpage = eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)) |> first
        toc = eachmatch(sel"div.toc", speechpage)
        if isempty(toc)
            lock(lk) do
                push!(speech, string(speechpage))
            end
        else
            for a in eachmatch(sel"a", first(toc))
                href = a.attributes["href"]
                href = occursin("#", href) ? first(split(href, '#')) : href
                url = BASE_PATH * href
                section = eachmatch(sel"div.section", scrape(url)) |> first
                lock(lk) do
                    push!(speech, string(section))
                end
            end
        end
        lock(lk) do
            push!(speeches, join(speech))
        end
    end
    join(speeches)
end


"""
    clean_date(date::String)::Date

Clean up date string and return Date object.

# Arguments
- `date::String`: Date in some string format

# Returns
- `::Date`: A Date object

# Examples
```jldoctest
julia> clean_date("January 3rd, 2009)")
2009-01-03
```
"""
function clean_date(date)
    try
        date = Date(date, DATEFMT)
    catch
        @warn "Date formatting error" date
        date = split(date)
        if length(date) ≠ 3 # no day given (just picks 1)
            @warn "possibly no day provided"
            m, y = date
            date = Date("$m 1, $y", DATEFMT)
        else
            @warn "day may contain 'th', 'st', etc."
            m, d, y = date
            d = filter(isnumeric, d)
            date = Date("$m $d, $y", DATEFMT)
        end
    finally
        return date
    end
end

"""
    check_url(resource_path::String, president::String, date::Date)

Try other common variations of URL format for missing or strangely formatted URLS

# Arguments
- `resource_path::String`: The resource path of the target url
- `president::String`: The President name
- `date::Date`: The date of the SOU speech

# Returns
- `url::String`: A new URL that wasn't empty OR
- `::NamedTuple`: A partially filled in DataFrame Record

# Examples
```julia
julia> check_url("", "William J. Clinton", Date(1998, 1, 28))
"https://infoplease.com/primary-sources/government/presidential-speeches/state-union-address-william-j-clinton-january-28-1998"
```
"""
function check_url(resource_path::String, president::String, date::Date)
    url = BASE_PATH * resource_path
    url = occursin("#", url) ? first(split(url, "#")) : url
    if isempty(eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)))
        @warn "No article found" url
        pres = join(filter(!ispunct, president) |> lowercase |> split, '-')
        dt = join([lowercase(monthname(date)), day(date), year(date)], '-')
        if isempty(resource_path) || !occursin(pres, resource_path) || !(occursin(dt, resource_path))
            @warn "Resource path error" resource_path
            url = BASE_PATH * "/" * LEADER * pres * '-' * dt
            @warn "attempting with new url" url
            if isempty(eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)))
                @warn "url failed" url
            else
                return url
            end
            url = BASE_PATH * "/" * pres * '-' * dt
            @warn "attempting with new url" url
            if isempty(eachmatch(sel"article[data-history-node-id#=(^[0-9]+$)]", scrape(url)))
                @warn "url failed" url
                return (; president=president, date=date, link=url, article_id=missing, data_history_node_id=missing, speech=missing)
            else
                return url
            end
        end
    end
    return url
end
