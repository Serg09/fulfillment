require 'csv'
require 'pp'

module ThreeDM
  class OrderImporter
    def self.order_field_map
      @order_field_map ||= {}
    end

    def self.shipping_address_field_map
      @shipping_address_field_map ||= {}
    end

    def self.item_field_map
      @item_field_map ||= {}
    end

    def self.add_order_field_mapping(external_field, internal_field, transform = nil)
      add_field_mapping order_field_map, external_field, internal_field, transform
    end

    def self.add_shipping_address_field_mapping(external_field, internal_field, transform = nil)
      add_field_mapping shipping_address_field_map, external_field, internal_field, transform
    end

    def self.add_item_field_mapping(external_field, internal_field, transform = nil)
      add_field_mapping item_field_map, external_field, internal_field, transform
    end

    def resolve_sku(sku)
      identifier = @client.book_identifiers.find_by(code: sku)
      raise "Unrecognized book identifier \"#{sku}\"" unless identifier
      identifier.book.isbn
    end

    def parse_date(value)
      match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.match(value)
      raise "Invalid order date \"#{value}\"" unless match
      Date.new(match[3].to_i, match[1].to_i, match[2].to_i)
    end

    FieldMapping = Struct.new(:key, :transform)
    def self.add_field_mapping(map, external_field, internal_field, transform = nil)
      map[external_field] = FieldMapping.new(internal_field, transform || ->(v){v})
    end

    add_order_field_mapping(:orderid, :client_order_id)
    add_order_field_mapping(:odate, :order_date, :parse_date)
    add_order_field_mapping(:oemail, :customer_email)
    add_order_field_mapping(:oshipmethod, :ship_method_id)
    add_order_field_mapping([:oshipfirstname, :oshiplastname], :customer_name)
    add_order_field_mapping(:oshipphone, :telephone)

    add_shipping_address_field_mapping([:oshipfirstname, :oshiplastname], :recipient)
    add_shipping_address_field_mapping(:oshipaddress, :line_1)
    add_shipping_address_field_mapping(:oshipaddress2, :line_2)
    add_shipping_address_field_mapping(:oshipcity, :city)
    add_shipping_address_field_mapping(:oshipstate, :state)
    add_shipping_address_field_mapping(:oshipzip, :postal_code)
    add_shipping_address_field_mapping(:oshipcountry, :country_code)

    add_item_field_mapping(:itemid, :sku, :resolve_sku)
    add_item_field_mapping(:itemname, :description)
    add_item_field_mapping(:numitems, :quantity)
    add_item_field_mapping(:unitprice, :unit_price)
    add_item_field_mapping(:weight, :weight)

    def initialize(content, client)
      @content = content
      @client = client
    end

    def process
      headers = nil

      Order.transaction do
        CSV.parse(@content) do |row|
          if headers.nil?
            headers = row
          else
            hash = [headers, row].transpose.to_h.with_indifferent_access
            process_row(hash)
          end
        end
      end
      true
    rescue => e
      Rails.logger.error "Error importing order file #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}"
      false
    end

    private

    def process_row(row)
      order_map = to_order_map(row)
      shipping_address_map = to_shipping_address_map(row)
      @order = create_or_keep_order(order_map, shipping_address_map)

      item_map = to_item_map(row)
      add_order_item(item_map)
    end

    def add_order_item(item_map)
      item = @order.items.lazy.select{|i| i.sku == item_map[:sku]}.first
      if item
        item.quantity += item_map[:quantity].to_i
        item.save!
      else
        @order.items.create! item_map
      end
    end

    def create_or_keep_order(order_map, shipping_address_map)
      if @order.try(:client_order_id) == order_map[:client_order_id]
        @order
      else
        @shipping_address = Address.create! shipping_address_map
        Order.create! order_map.merge(client: @client,
                                      shipping_address_id: @shipping_address.id)
      end
    end

    def to_order_map(row)
      map_fields(row, self.class.order_field_map) #TODO Add the client ID
    end

    def to_shipping_address_map(row)
      map_fields(row, self.class.shipping_address_field_map)
    end

    def count
      @count ||= 0
    end

    def count=(value)
      @count = value
    end

    def to_item_map(row)
      map_fields row, self.class.item_field_map
    end

    def map_fields(row, field_map)
      field_map.reduce({}) do |result, pair|
        external_field = pair.first
        mapping = pair.second
        if external_field.is_a? Array
          #TODO how to support transforms on concantenations?
          result[mapping.key] = external_field.map{|k| row[k]}.join(" ")
        else
          raw_value = row[external_field]
          if mapping.transform.is_a? Symbol
            result[mapping.key] = send(mapping.transform, raw_value)
          else
            result[mapping.key] = mapping.transform.call(raw_value)
          end
        end
        result
      end
    end
  end
end
