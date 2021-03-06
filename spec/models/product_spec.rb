require 'rails_helper'

RSpec.describe Product, type: :model do
  let (:attributes) do
    {
      sku: '123456',
      description: 'Deluxe Widget',
      price: '14.99',
      weight: '2.2'
    }
  end

  it 'can be created from valid attributes' do
    product = Product.new attributes
    expect(product).to be_valid
  end

  describe '#sku' do
    it 'is required' do
      product = Product.new attributes.except(:sku)
      expect(product).to have(1).error_on(:sku)
    end

    it 'must be unique' do
      p1 = Product.create! attributes
      p2 = Product.new attributes
      expect(p2).to have(1).error_on(:sku)
    end

    it 'cannot be more than 20 characters' do
      product = Product.new attributes.merge(sku: 'x' * 21)
      expect(product).to have(1).error_on(:sku)
    end
  end

  describe '#description' do
    it 'is required' do
      product = Product.new attributes.except(:description)
      expect(product).to have(1).error_on(:description)
    end

    it 'cannot be more than 256 characters' do
      product = Product.new attributes.merge(description: 'x' * 257)
      expect(product).to have(1).error_on(:description)
    end
  end

  describe '#price' do
    it 'is required' do
      product = Product.new attributes.except(:price)
      expect(product).to have(1).error_on(:price)
    end

    it 'must be more than zero' do
      product = Product.new attributes.merge(price: 0)
      expect(product).to have(1).error_on(:price)
    end
  end

  describe '#weight' do
    context 'for a product with physical fulfillment' do
      it 'is required' do
        product = Product.new attributes.except(:weight)
        expect(product).to have(1).error_on(:weight)
      end
    end

    context 'for a product with electronic fulfillment' do
      it 'may be nil' do
        product = Product.new attributes.
          except(:weight).
          merge(fulfillment_type: :electronic)
        expect(product).to be_valid
      end
    end

    it 'must be a number' do
      product = Product.new attributes.merge(weight: 'abc')
      expect(product).to have(1).error_on(:weight)
    end

    it 'must be more than zero' do
      product = Product.new attributes.merge(weight: -1)
      expect(product).to have(1).error_on(:weight)
    end
  end

  describe '#fulfillment_type' do
    it 'defaults to "physical"' do
      product = Product.new attributes
      expect(product.fulfillment_type).to eq 'physical'
    end

    it 'can be "electronic"' do
      product = Product.new attributes.merge(fulfillment_type: 'electronic')
      expect(product).to be_valid
    end

    it 'cannot be anything except "physical" or "electronic"' do
      product = Product.new attributes.merge(fulfillment_type: 'wishing')
      expect(product).to have(1).error_on :fulfillment_type
    end
  end
end
