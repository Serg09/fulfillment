# == Schema Information
#
# Table name: ship_methods
#
#  id           :integer          not null, primary key
#  carrier_id   :integer          not null
#  description  :string(100)      not null
#  abbreviation :string(20)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class ShipMethod < ActiveRecord::Base
  belongs_to :carrier
  validates_presence_of :description,
    :carrier_id,
    :abbreviation,
    :calculator_class
  validates_length_of :description, maximum: 100
  validates_length_of :abbreviation, maximum: 20
  validates_uniqueness_of :description, scope: :carrier_id
  validates_uniqueness_of :abbreviation

  FREIGHT_CHARGE_SKU = 'FREIGHT'

  def calculate_charge(order)
    calculator.calculate order
  end

  private

  def calculator
    @calculator ||= calculator_class.constantize.new
  end
end
