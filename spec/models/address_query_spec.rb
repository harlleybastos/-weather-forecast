require "rails_helper"

RSpec.describe AddressQuery do
  it "is valid with an address" do
    expect(described_class.new(address: "1 Infinite Loop, Cupertino")).to be_valid
  end

  it "squishes surrounding and repeated whitespace" do
    expect(described_class.new(address: "  1  Infinite   Loop ").address).to eq("1 Infinite Loop")
  end

  it "requires an address" do
    [ nil, "", "    " ].each do |blank|
      query = described_class.new(address: blank)

      expect(query).to be_invalid
      expect(query.errors[:address]).to include("can't be blank")
    end
  end

  it "rejects overly long input before it reaches upstream APIs" do
    query = described_class.new(address: "a" * (AddressQuery::MAX_LENGTH + 1))

    expect(query).to be_invalid
    expect(query.errors[:address].first).to match(/too long/)
  end
end
