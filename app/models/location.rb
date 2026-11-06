Location = Data.define(:display_name, :postal_code, :country_code, :latitude, :longitude) do
  def postal_code?
    postal_code.present?
  end

  # Forecasts are cached per postal code. The country prefix keeps identical
  # codes from different countries (e.g. "10115") from sharing an entry.
  def postal_code_key
    "#{country_code}/#{postal_code}"
  end
end
