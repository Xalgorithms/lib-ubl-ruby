require_relative '../xml/parse'
require_relative '../xml/maybes'

module XA
  module UBL
    module Invoice
      include XML::Parse
      include XML::Maybes
      
      def ns(n, k)
        if !@nses
          @namespace_urns ||= {
            invoice: 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2',
            cac:     'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2',
            cbc:     'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2',
            ccp:     'urn:oasis:names:specification:ubl:schema:xsd:CoreComponentParameters-2',
            cec:     'urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2',
            sdt:     'urn:oasis:names:specification:ubl:schema:xsd:SpecializedDatatypes-2',
            udt:     'urn:un:unece:uncefact:data:specification:UnqualifiedDataTypesSchemaModule:2',
          }
          nses = n.namespaces.invert
          @nses = @namespace_urns.keys.inject({}) do |o, k|
            ns_k = @namespace_urns[k]
            nses[ns_k] ? o.merge(k => nses[ns_k].split(':').last) : o
          end
        end
        
        @nses[k]
      end

      def parse_urn(urn, &bl)
        load_and_parse_urn(urn, :root_xp, :make_invoice, &bl)
      end

      def parse(b, &bl)
        load_and_parse(b, :root_xp, :make_invoice, &bl)
      end
      
      def root_xp(doc)
        "#{ns(doc, :invoice)}:Invoice"
      end
      
      def maybe_find_period(el, &bl)
        period_set = {
          starts: "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:StartDate",
          ends:   "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:EndDate",
        }
        
        maybe_find_set_text(el, period_set) do |s|
          bl.call(s) if bl
        end
      end
      
      def maybe_find_parties(el, &bl)
        parties_set = {
          supplier: "#{ns(el, :cac)}:AccountingSupplierParty/#{ns(el, :cac)}:Party",
          customer: "#{ns(el, :cac)}:AccountingCustomerParty/#{ns(el, :cac)}:Party",
          payer:    "#{ns(el, :cac)}:PayeeParty",
        }
        maybe_find_set(el, parties_set) do |parties_els|
          parties = parties_els.inject({}) do |o, kv|
            o.merge(kv.first => make_party(kv.last))
          end
          bl.call(parties) if parties.any? && bl
        end
      end

      def maybe_find_delivery(el, &bl)
        rv = {}
        maybe_find_one(el, "#{ns(el, :cac)}:Delivery") do |delivery_el|
          maybe_find_one_text(delivery_el, "#{ns(el, :cbc)}:ActualDeliveryDate") do |text|
            rv[:date] = text
          end

          # skipping DL/ID
          maybe_find_one_convert(
            :make_address, delivery_el,
            "#{ns(delivery_el, :cac)}:DeliveryLocation/#{ns(delivery_el, :cac)}:Address") do |address|
            rv[:address] = address
          end
        end

        bl.call(rv) if rv.any? && bl
        rv
      end

      def maybe_find_id(el, xp = nil, &bl)
        lxp = [xp, "#{ns(el, :cbc)}:ID"].compact.join('/')
        maybe_find_one_convert(:make_id, el, lxp, &bl)
      end

      def make_id(el)
        {
          value: el.text,
        }.tap do |o|
          o[:scheme] = el['schemeID'] if el['schemeID']
          o[:agency] = el['schemeAgencyID'] if el['schemeAgencyID']
        end
      end
      
      def make_invoice(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:ID") do |text|
            o[:id] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:IssueDate") do |text|
            o[:issued] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:DocumentCurrencyCode") do |text|
            o[:currency] = text
          end
          
          maybe_find_period(el) do |period|
            o[:period] = period
          end
          
          maybe_find_parties(el) do |parties|
            o[:parties] = parties
          end

          maybe_find_delivery(el) do |delivery|
            o[:delivery] = delivery
          end

          # add PaymentMeans && PaymentTerms (needs looking at spec)
          maybe_find_many_convert(:make_line, el, "#{ns(el, :cac)}:InvoiceLine") do |lines|
            o[:lines] = lines
          end
        end
      end
      
      def make_party(party_el)
        # ignoring: cbc:EndpointID, cbc:ID
        {}.tap do |o|
          maybe_find_one_text(party_el, "#{ns(party_el, :cac)}:PartyIdentification/#{ns(party_el, :cbc)}:ID") do |text|
            o[:id] = text
          end
          maybe_find_one_text(party_el, "#{ns(party_el, :cac)}:PartyName/#{ns(party_el, :cbc)}:Name") do |text|
            o[:name] = text
          end
          maybe_find_one_convert(:make_address, party_el, "#{ns(party_el, :cac)}:PostalAddress") do |a|
            o[:address] = a
          end
          maybe_find_one_convert(:make_legal, party_el, "#{ns(party_el, :cac)}:PartyLegalEntity") do |l|
            o[:legal] = l
          end
          maybe_find_one_convert(:make_contact, party_el, "#{ns(party_el, :cac)}:Contact") do |contact|
            o[:contact] = contact
          end
          maybe_find_one_convert(:make_person, party_el, "#{ns(party_el, :cac)}:Person") do |person|
            o[:person] = person
          end
        end
      end
      
      def make_address(n)
        {}.tap do |o|
          maybe_find_id(n) do |id|
            o[:id] = id
          end

          street_set = {
            name: "#{ns(n, :cbc)}:StreetName",
            unit: "#{ns(n, :cbc)}:AdditionalStreetName",
          }
          maybe_find_set_text(n, street_set) do |street|
            o[:street] = street
          end

          maybe_find_one_text(n, "#{ns(n, :cbc)}:BuildingNumber") do |text|
            o[:number] = text
          end

          additional_set = {
            department: "#{ns(n, :cbc)}:Department",
          }
          maybe_find_set_text(n, additional_set) do |additional|
            o[:additional] = additional
          end
          
          maybe_find_one_text(n, "#{ns(n, :cbc)}:CountrySubentityCode") do |text|
            o[:region] = text
          end

          maybe_find_one_text(n, "#{ns(n, :cbc)}:PostalZone") do |text|
            o[:zone] = text
          end
          
          maybe_find_one_text(n, "#{ns(n, :cbc)}:CityName") do |text|
            o[:city] = text
          end
          maybe_find_one_text(n, "#{ns(n, :cac)}:Country/#{ns(n, :cbc)}:IdentificationCode") do |text|
            o[:country_code] = text
          end
        end
      end

      def make_legal(n)
        # not handling cbc:CompanyID
        {}.tap do |o|
          maybe_find_one_text(n, "#{ns(n, :cbc)}:RegistrationName") do |text|
            o[:name] = text
          end
          maybe_find_one_convert(:make_address, n, "#{ns(n, :cac)}:RegistrationAddress") do |a|
            o[:address] = a
          end
        end
      end

      def make_contact(n)
        {}.tap do |o|
          maybe_find_one_text(n, "#{ns(n, :cbc)}:Telephone") do |text|
            o[:telephone] = text
          end
          maybe_find_one_text(n, "#{ns(n, :cbc)}:Telefax") do |text|
            o[:fax] = text
          end
          maybe_find_one_text(n, "#{ns(n, :cbc)}:ElectronicMail") do |text|
            o[:email] = text
          end
        end
      end

      def make_person(n)
        @names_set ||= {
          first:  "#{ns(n, :cbc)}:FirstName",
          family: "#{ns(n, :cbc)}:FamilyName",
          other:  "#{ns(n, :cbc)}:OtherName",
          middle: "#{ns(n, :cbc)}:MiddleName",
        }
        {}.tap do |o|
          maybe_find_set_text(n, @names_set) do |names|
            o[:name] = names
          end
          maybe_find_one_text(n, "#{ns(n, :cbc)}:JobTitle") do |text|
            o[:title] = text
          end
        end
      end

      def make_line(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:Note") do |text|
            o[:note] = text
          end
          maybe_find_one_convert(:make_line_item, el, "#{ns(el, :cac)}:Item") do |item|
            o[:item] = item
          end
          maybe_find_one_convert(:make_line_price, el, "#{ns(el, :cac)}:Price") do |price|
            o[:price] = price
          end
        end
      end

      def maybe_find_line_item_ids(el, &bl)
        @line_item_ids ||= {
          seller:   "#{ns(el, :cac)}:SellersItemIdentification",
          standard: "#{ns(el, :cac)}:StandardItemIdentification",
        }

        ids = @line_item_ids.inject({}) do |oids, kv|
          maybe_find_id(el, kv.last) do |id|
            oids = oids.merge(kv.first => id)
          end
          
          oids
        end
        
        bl.call(ids) if ids.any? && bl
      end

      def maybe_find_line_item_classifications(el, &bl)
        xp = "#{ns(el, :cac)}:CommodityClassification/#{ns(el, :cbc)}:ItemClassificationCode"
        maybe_find_many_convert(:make_classification, el, xp, &bl)
      end

      def make_classification(el)
        {
          value: el.text
        }.tap do |o|
          o[:agency] = el['listAgencyID'] if el['listAgencyID']
          o[:id] = el['listID'] if el['listID']
        end
      end

      def maybe_find_tax_category(el, &bl)
        maybe_find_one_convert(:make_tax_category, el, "#{ns(el, :cac)}:ClassifiedTaxCategory", &bl)
      end

      def make_tax_category(el)
        {}.tap do |o|
          maybe_find_id(el) do |id|
            o[:id] = id
          end
          maybe_find_one_int(el, "#{ns(el, :cbc)}:Percent") do |percent|
            o[:percent] = percent
          end
          maybe_find_id(el, "#{ns(el, :cac)}:TaxScheme") do |id|
            o[:scheme] = id
          end
        end
      end

      def make_item_property(el)
        {}.tap do |o|
          { k: 'Name', v: 'Value' }.each do |k, v|
            maybe_find_one_text(el, "#{ns(el, :cbc)}:#{v}") do |text|
              o[k] = text
            end
          end
        end
      end
      
      def make_line_item(el)
        {}.tap do |o|
          maybe_find_one_tagged_text(el, "#{ns(el, :cbc)}:Description") do |desc|
            o[:description] = desc
          end

          maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |name|
            o[:name] = name
          end

          maybe_find_line_item_ids(el) do |ids|
            o[:ids] = ids
          end

          maybe_find_line_item_classifications(el) do |classifications|
            o[:classifications] = classifications
          end

          maybe_find_tax_category(el) do |category|
            o[:tax_category] = category
          end

          maybe_find_many_convert(:make_item_property, el, "#{ns(el, :cac)}:AdditionalItemProperty") do |props|
            o[:props] = props.inject({}) do |o, kv|
              o.merge(kv[:k] => kv[:v])
            end
          end
        end
      end

      def make_line_price(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:PriceAmount", ['currencyID']) do |text, vals|
            currency = vals.fetch('currencyID', nil)
            o[:currency] = currency if currency
            o[:amount] = text.to_f
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:BaseQuantity", ['unitCode']) do |text, vals|
            code = vals.fetch('unitCode', nil)
            o[:code] = code if code
            o[:quantity] = text.to_i
          end
        end
      end
    end
  end
end
