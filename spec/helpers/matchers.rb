require 'nokogiri'
require 'uri'

RSpec::Matchers.define :usps_param do |css, expected|

  def parse_xml(url)
    uri = URI(url)

    array  = uri.query.
      split('&').
      map{|pair| pair.split('=', 2)}
    hash = Hash[array]
    encoded_xml = hash['XML']
    xml = URI.unescape(encoded_xml)
    Nokogiri::XML(xml)
  end

  match do |actual|
    begin
      xml = parse_xml(actual)
      xml.at_css(css).content == expected
    rescue Exception => e
      false
    end
  end

  description do
    "XML param value '#{expected}' in the XML at '#{css}'"
  end

  failure_message do |actual|
    "expected XML to have '#{expected}' at '#{css}', but it didn't: #{parse_xml(actual)}"
  end

  failure_message_when_negated do |actual|
    "expected XML not to have '#{expected}' at '#{css}', but it did: #{parse_xml(actual)}"
  end
end

RSpec::Matchers.define :include_sku do |product_or_sku|
  sku = (product_or_sku.respond_to?(:sku) ?
         product_or_sku.sku :
         product_or_sku).upcase

  match do |content|
    begin
      index = (content || "").index sku
      !!index
    rescue
      false
    end
  end

  failure_message do |actual|
    "expected the content to include the SKU \"#{sku}\""
  end

  failure_message_when_negated do |actual|
    "expected the content not to include the SKU \"#{sku}\""
  end
end
