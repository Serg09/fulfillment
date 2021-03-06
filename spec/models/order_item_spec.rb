require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  let (:order) { FactoryGirl.create(:order) }
  let (:attributes) do
    {
      order_id: order.id,
      sku: 'ABC123',
      quantity: 1,
      description: 'My Book',
      unit_price: 19.99,
      discount_percentage: 0.0,
      tax: 1.65
    }
  end

  it 'can be created from valid attributes' do
    item = OrderItem.new attributes
    expect(item).to be_valid
  end

  describe '#order_id' do
    it 'is required' do
      item = OrderItem.new attributes.except(:order_id)
      expect(item).to have_at_least(1).error_on :order_id
    end
  end

  describe '#order' do
    it 'is a reference to the order to which the item belongs' do
      item = OrderItem.new attributes
      expect(item.order).to eq order
    end
  end

  describe '#line_item_no' do
    it 'is automatically set to the next available value' do
      item = OrderItem.create! attributes
      expect(item.line_item_no).to eq 1
    end
  end

  describe '#sku' do
    it 'is required' do
      item = OrderItem.new attributes.except(:sku)
      expect(item).to have_at_least(1).error_on :sku
    end

    it 'cannot be more than 30 characters' do
      item = OrderItem.new attributes.merge(sku: 'x' * 31)
      expect(item).to have_at_least(1).error_on :sku
    end

    it 'is unique within the order' do
      i1 = OrderItem.create! attributes
      i2 = OrderItem.new attributes
      expect(i2).to have_at_least(1).error_on :sku
    end

    it 'can be duplicated across orders' do
      i1 = OrderItem.create! attributes
      i2 = OrderItem.new attributes.merge(order_id: FactoryGirl.create(:order).id)
      expect(i2).to be_valid
    end
  end

  describe '#description' do
    it 'cannot be longer than 250 characters' do
      item = OrderItem.new attributes.merge(description: 'x' * 251)
      expect(item).to have_at_least(1).error_on :description
    end
  end

  describe '#quantity' do
    it 'is required' do
      item = OrderItem.new attributes.except(:quantity)
      expect(item).to have_at_least(1).error_on :quantity
    end

    context 'on create' do
      it 'must be greater than zero' do
        item = OrderItem.new attributes.merge(quantity: 0)
        expect(item).to have_at_least(1).error_on :quantity
      end
    end

    context 'on update' do
      it 'can be zero' do
        item = OrderItem.create! attributes
        item.quantity = 0
        expect(item).to be_valid
      end

      it 'cannot be less than 0' do
        item = OrderItem.create! attributes
        item.quantity = -1
        expect(item).to have_at_least(1).error_on :quantity
      end
    end
  end

  describe '#unit_price' do
    it 'cannot be less than' do
      item = OrderItem.new attributes.merge(unit_price: -0.01)
      expect(item).to have_at_least(1).error_on :unit_price
    end
  end

  describe '#discount_percentage' do
    it 'cannot be less than zero' do
      item = OrderItem.new attributes.merge(discount_percentage: -0.01)
      expect(item).to have_at_least(1).error_on :discount_percentage
    end
  end

  describe '#tax' do
    it 'cannot be less than zero' do
      item = OrderItem.new attributes.merge(tax: -0.01)
      expect(item).to have_at_least(1).error_on :tax
    end
  end

  describe '#fulfillment_type' do
    it 'defaults to "physical"' do
      item = OrderItem.new attributes
      expect(item.fulfillment_type).to eq 'physical'
    end

    it 'can be "electronic"' do
      item = OrderItem.new attributes.merge(fulfillment_type: 'electronic')
      expect(item).to be_valid
    end

    it 'can be "none"' do
      item = OrderItem.new attributes.merge(fulfillment_type: 'none')
      expect(item).to be_valid
    end

    it 'cannot be anything other than "physical" or "electronic", or "none"' do
      item = OrderItem.new attributes.merge(fulfillment_type: 'hoping')
      expect(item).to have(1).error_on(:fulfillment_type)
    end
  end

  describe '#total_price' do
    let(:item) do
      FactoryGirl.create(:order_item, unit_price: 20,
                                      quantity: 2,
                                      tax: 1.60)
    end
    it 'is the sum of #unit_price * quantity, and #tax' do
      expect(item.total_price).to eq 41.60
    end
  end

  describe '#standard_item?' do
    context 'for a regular, user-added item' do
      let (:item) { FactoryGirl.create(:order_item, sku: '1234') }
      it 'returns true' do
        expect(item.standard_item?).to be true
      end
    end

    context 'for a special, system-added item' do
      let (:item) { FactoryGirl.create(:order_item, sku: ShipMethod::FREIGHT_CHARGE_SKU) }
      it 'returns false' do
        expect(item.standard_item?).to be false
      end
    end
  end

  describe '#shipment_items' do
    it 'is a list of shipment items associated with the order item' do
      item = OrderItem.new attributes
      expect(item).to have(0).shipment_items
    end
  end

  shared_context :processing do
    let (:order_item) { FactoryGirl.create(:order_item, order: order, quantity: 3) }
  end

  shared_context :partial_shipment do
    include_context :processing

    let!(:shipment) { FactoryGirl.create(:shipment, order: order) }
    let!(:shipment_item_1) do
      FactoryGirl.create(:shipment_item, shipment: shipment,
                                         order_item: order_item,
                                         shipped_quantity: 1)
    end
    let!(:shipment_item_2) do
      FactoryGirl.create(:shipment_item, shipment: shipment,
                                         order_item: order_item,
                                         shipped_quantity: 1)
    end
    before { order_item.shipment_items(true) }
  end

  shared_context :full_shipment do
    include_context :partial_shipment
    let!(:shipment_item_3) do
      FactoryGirl.create(:shipment_item, shipment: shipment,
                                         order_item: order_item,
                                         shipped_quantity: 1)
    end
    before { order_item.shipment_items(true) }
  end

  describe '#total_shipped_quantity' do
    include_context :partial_shipment

    it 'is the total quantity of the item that has been shipped' do
      expect(order_item.total_shipped_quantity).to eq 2
    end
  end

  context 'when no items have shipped' do
    include_context :processing

    describe '#all_items_shipped?' do
      it 'is false' do
        expect(order_item).not_to be_all_items_shipped
      end
    end
    describe '#some_items_shipped?' do
      it 'is false' do
        expect(order_item).not_to be_some_items_shipped
      end
    end
  end

  context 'when some but not all items have shipped' do
    include_context :partial_shipment

    describe '#all_items_shipped?' do
      it 'is false' do
        expect(order_item).not_to be_all_items_shipped
      end
    end
    describe '#some_items_shipped?' do
      it 'is true' do
        expect(order_item).to be_some_items_shipped
      end
    end
  end

  context 'when all items have shipped' do
    include_context :full_shipment

    describe '#all_items_shipped?' do
      it 'is true' do
        expect(order_item).to be_all_items_shipped
      end
    end
    describe '#some_items_shipped?' do
      it 'is true' do
        expect(order_item).to be_some_items_shipped
      end
    end
  end
end
