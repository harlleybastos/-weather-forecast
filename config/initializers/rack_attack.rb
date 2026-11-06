# Per-IP counters are shared through Rails.cache. This does not enforce
# an aggregate rate limit across clients for the upstream services.
class Rack::Attack
  throttle("forecasts/ip", limit: Integer(ENV.fetch("FORECAST_THROTTLE_PER_MINUTE", 30)), period: 1.minute) do |request|
    request.ip if request.get? && request.path == "/" && request.params["address"].present?
  end

  self.throttled_responder = lambda do |request|
    retry_after = request.env["rack.attack.match_data"].to_h.fetch(:period, 60)
    [ 429, { "content-type" => "text/plain", "retry-after" => retry_after.to_s }, [ I18n.t("forecasts.errors.throttled") ] ]
  end
end
