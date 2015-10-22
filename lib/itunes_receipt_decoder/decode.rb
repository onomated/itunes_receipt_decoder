module ItunesReceiptDecoder
  class Decode
    attr_accessor :receipt_data
    attr_accessor :receipt

    def initialize(receipt_data)
      @receipt_data = Base64.strict_decode64(receipt_data)
      @receipt = {}
    end

    def decode
      parse_app_receipt_fields(payload.value)
      receipt
    end

    def app_receipt_fields
      {
        2 => :bundle_id,
        3 => :application_version,
        12 => :creation_date,
        17 => :in_app,
        19 => :original_application_version,
        21 => :expiration_date
      }
    end

    def in_app_purchase_receipt_fields
      {
        1701 => :quantity,
        1702 => :product_id,
        1703 => :transaction_id,
        1705 => :original_transaction_id,
        1704 => :purchase_date,
        1706 => :original_purchase_date,
        1708 => :expires_date,
        1712 => :cancellation_date,
        1711 => :web_order_line_item_id
      }
    end

    def parse_app_receipt_fields(data)
      data.each do |seq|
        type = seq.value[0].value.to_i
        next unless field = app_receipt_fields[type]
        value = OpenSSL::ASN1.decode(seq.value[2].value).value
        if field == :in_app
          receipt[field] ||= []
          receipt[field].push(parse_in_app_purchase_receipt_fields(value))
        else
          receipt[field] = value
        end
      end
    end

    def parse_in_app_purchase_receipt_fields(data)
      result = {}
      data.each do |seq|
        type = seq.value[0].value.to_i
        next unless field = in_app_purchase_receipt_fields[type]
        value = OpenSSL::ASN1.decode(seq.value[2].value).value
        result[field] = value.to_s
      end
      result
    end

    private

    def payload
      @payload ||= OpenSSL::ASN1.decode(pkcs7.data)
    end

    def pkcs7
      return @pkcs7 if @pkcs7
      @pkcs7 = OpenSSL::PKCS7.new(receipt_data)
      @pkcs7.verify(nil, Config.certificate_store, nil, nil)
      @pkcs7
    end
  end
end
