"""
    scrape(url::String)

Scrapes a URL and returns a Gumbo object

# Arguments
- `url::String`: The target URL

# Returns

# Examples

"""
function scrape(url::String)
    resp = HTTP.get(url)
    root = resp.body |> String |> parsehtml
end
