module Freight
  class BaseCalculator
    attr_accessor :order

    def rate
      @rate ||= calculate_rate
    end

    protected

    def calculate_rate
      raise 'BaseCalculator#rate must be overriden in a derived class'
    end

    def total_weight
      @total_weight ||= order.items.reduce(0) do |sum, item|
        product = Product.find_by_sku(item.sku)
        item_weight = product.present? ?
          product.weight * item.quantity :
          0
        sum + item_weight
      end
    end
  end
end