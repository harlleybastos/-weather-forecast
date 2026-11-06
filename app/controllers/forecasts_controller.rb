class ForecastsController < ApplicationController
  def show
    @query = AddressQuery.new(address: params[:address])
    return if params[:address].nil?

    if @query.invalid?
      render :show, status: :unprocessable_entity
    else
      @result = forecast_lookup.call(@query.address)
    end
  rescue ForecastLookup::AddressNotFound
    render_error :address_not_found, :unprocessable_entity
  rescue ForecastLookup::PostalCodeNotFound
    render_error :postal_code_not_found, :unprocessable_entity
  rescue ExternalApi::RateLimitedError => e
    log_upstream_failure(e)
    render_error :rate_limited, :service_unavailable
  rescue ExternalApi::Error => e
    log_upstream_failure(e)
    render_error :upstream_unavailable, :service_unavailable
  end

  private

  def forecast_lookup
    ForecastLookup.new
  end

  def log_upstream_failure(error)
    cause = " (caused by #{error.cause.class}: #{error.cause.message})" if error.cause
    Rails.logger.warn("[forecast] #{error.class}: #{error.message}#{cause}")
  end

  def render_error(key, status)
    @error = t("forecasts.errors.#{key}")
    render :show, status: status
  end
end
