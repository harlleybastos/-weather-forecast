class AddressQuery
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_LENGTH = 200

  attribute :address, :string

  validates :address, presence: true, length: { maximum: MAX_LENGTH }

  def address=(value)
    super(value.to_s.squish.presence)
  end
end
