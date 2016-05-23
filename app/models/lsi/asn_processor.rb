module Lsi
  class AsnProcessor
    def initialize(content)
      @content = content
    end

    def process
      reader = Lsi::AsnReader.new(@content)
      reader.read.reduce(true){|result, r| process_record(r) && result}
    end

    private

    def process_record(record)
      @order = Order.find(record[:order_id]) if record[:order_id]
      case record[:header]
      when '$$HDR'
        Rails.logger.info "Processing advanced shipping notification for batch #{record[:batch_id]}"
        true
      when 'O'
        process_order(record)
      when 'I'
        process_item(record)
      when 'P'
        process_package(record)
      else
        true
      end
    rescue => e
      Rails.logger.error "Error processing record #{record.inspect} #{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
    end

    def process_order(record)
      @shipment = @order.shipments.create! external_id: record[:shipment_id],
                                           ship_date: record[:ship_date],
                                           quantity: record[:ship_quantity],
                                           weight: record[:weight],
                                           freight_charge: record[:freight_charge],
                                           handling_charge: record[:handling_charge],
                                           collect_freight: record[:collect_freight] == 'Y',
                                           freight_responsibility: record[:freight_responsibility] == 'C' ? 'customer' : 'publisher',
                                           cancel_code: record[:cancel_code],
                                           cancel_reason: record[:cancel_reason]
    end

    def process_item(record)
      order_item = @order.items.find_by(line_item_no: record[:line_item_no])
      if order_item
        @shipment_item = @shipment.items.create! order_item: order_item,
                                                external_line_no: record[:lsi_line_item_no],
                                                sku: record[:sku_10] || record[:sku_13],
                                                price: record[:price],
                                                shipped_quantity: record[:shipped_quantity],
                                                cancel_code: record[:cancel_code],
                                                cancel_reason: record[:cancel_reason]
        if item.all_items_shipped?
          item.ship
        elsif item.some_items_shipped?
          item.ship_partial
        end
      else
        Rails.logger.warn "Unable to process shipment item: order item not found: #{record.inspect}"
      end
    end

    def process_package(record)
    end
  end
end
