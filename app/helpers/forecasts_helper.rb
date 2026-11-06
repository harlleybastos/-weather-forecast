module ForecastsHelper
  def format_temperature(value, unit)
    return "—" if value.nil?

    "#{value.round}#{unit}"
  end

  def cache_badge(result)
    if result.cached?
      tag.span("Cached", class: "badge badge--cached", title: "Served from cache, fetched #{time_ago_in_words(result.fetched_at)} ago")
    else
      tag.span("Live", class: "badge badge--live", title: "Fetched from the weather service just now")
    end
  end
end
