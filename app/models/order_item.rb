# == Schema Information
#
# Table name: order_items
#
#  id                  :integer          not null, primary key
#  order_id            :integer          not null
#  line_item_no        :integer          not null
#  sku                 :string(30)       not null
#  description         :string(50)
#  quantity            :integer          not null
#  unit_price          :decimal(, )
#  discount_percentage :decimal(, )
#  tax                 :decimal(, )
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  status              :string(30)       default("new"), not null
#  accepted_quantity   :integer
#  shipped_quantity    :integer
#  weight              :decimal(, )
#  fulfillment_type    :string(15)       default("physical"), not null
#

class OrderItem < ActiveRecord::Base
  include AASM

  FULFILLMENT_TYPES = Product::FULFILLMENT_TYPES + ['none']

  belongs_to :order
  has_many :shipment_items

  before_create :set_line_item_number
  after_create :refresh_order, if: :standard_item?
  after_destroy :refresh_order, if: :standard_item?
  after_update :update_freight_charge, if: :standard_item?

  validates_presence_of :order_id,
                        :sku,
                        :quantity,
                        :fulfillment_type

  validates_inclusion_of :fulfillment_type, in: FULFILLMENT_TYPES

  validates_length_of :sku, maximum: 30
  validates_length_of :description, maximum: 250

  validates_uniqueness_of :sku, scope: :order_id

  validates_numericality_of :quantity, greater_than: 0, on: :create, if: :quantity
  validates_numericality_of :quantity, greater_than: -1, on: :update, if: :quantity
  [:unit_price,
   :discount_percentage,
   :tax].each{|f| validates_numericality_of f, greater_than_or_equal_to: 0, if: f}

  before_validation :set_defaults

  scope :physical, ->{where fulfillment_type: 'physical'}
  scope :electronic, ->{where fulfillment_type: 'electronic'}

  aasm(:status, whiny_transitions: false) do
    state :new, initial: true
    state :processing, :partially_shipped, :shipped, :rejected, :back_ordered, :cancelled

    event :acknowledge do
      transitions from: :new, to: :processing
    end

    event :ship do
      after { order.ship! }
      transitions from: [:new, :processing, :partially_shipped],
        to: :shipped,
        if: :all_items_shipped?
      transitions from: [:new, :processing], to: :partially_shipped
    end

    event :reject do
      before{ self.accepted_quantity = 0 }
      transitions from: :new, to: :rejected
    end

    event :cancel do
      before{ self.accepted_quantity = 0 }
      transitions from: :new, to: :cancelled
    end

    event :back_order do
      transitions from: :new, to: :back_ordered
    end
  end

  def total_price
    [extended_price, tax].compact.reduce &:+
  end

  def total_shipped_quantity
    shipment_items.reduce(0){|s, i| s + i.shipped_quantity}
  end

  def all_items_shipped?
    total_shipped_quantity >= quantity
  end

  def some_items_shipped?
    total_shipped_quantity > 0
  end

  def too_many_items_shipped?
    total_shipped_quantity > quantity
  end

  def extended_price
    return 0 unless unit_price.present? && quantity.present?
    unit_price * quantity
  end

  def standard_item?
    sku != ShipMethod::FREIGHT_CHARGE_SKU
  end

  Product::FULFILLMENT_TYPES.each do |t|
    define_method "#{t}_delivery?" do
      fulfillment_type == t
    end
  end

  private

  def set_defaults
    self.discount_percentage = 0 unless discount_percentage
    self.tax = 0 unless tax
  end

  def set_line_item_number
    self.line_item_no = order.items.count + 1
  end

  def refresh_order
    order.reset_line_numbers
    order.update_freight_charge!
  end

  def update_freight_charge
    order.update_freight_charge!
  end
end
