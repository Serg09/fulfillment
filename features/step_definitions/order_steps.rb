Given /^"([^"]+)" ordered "([^"]+)" - "([^"]+)" for (#{DOLLAR_AMOUNT}) on (#{DATE})$/ do |customer_name, sku, description, price, date|
  order = FactoryGirl.create(:order, customer_name: customer_name,
                                     order_date: date)
  item = FactoryGirl.create(:order_item, order: order,
                                         sku: sku,
                                         quantity: 1,
                                         description: description,
                                         price: price,
                                         tax: price * 0.0825,
                                         freight_charge: 0)
end