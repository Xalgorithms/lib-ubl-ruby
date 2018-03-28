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

      def make_invoice(el)
        {}.tap do |o|
          o['envelope'] = extract_envelope(el)
          o['items'] = extract_items(el)
        end
      end

      def extract_envelope(el)
        {}.tap do |o|
          date_set = {
            'date' => "#{ns(el, :cbc)}:IssueDate",
            'time' => "#{ns(el, :cbc)}:IssueTime",
          }
          period_set = {
            'starts' => "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:StartDate",
            'ends'  => "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:EndDate",
          }
        
          o['document_ids'] = extract_document_ids(el)

          maybe_find_set_text(el, date_set) do |vals|
            o['issued'] = "#{vals['date']}" + (vals.key?('time') ? "T#{vals['time']}" : '')
          end

          maybe_find_set_text(el, period_set) do |vals|
            o['period'] = vals
          end
          
          maybe_find_one_text(el, "#{ns(el, :cbc)}:DocumentCurrencyCode") do |text|
            o['currency'] = text
          end

          maybe_find_parties(el) do |parties|
            o['parties'] = parties
          end
        end
      end
      
      def extract_items(el)
        maybe_find_many_convert(:extract_item, el, "#{ns(el, :cac)}:InvoiceLine")
      end

      def extract_item(el)
        {}.tap do |o|
          maybe_find_identifier(el, '.') do |id|
            o['id'] = id
          end
          maybe_find_one(el, "#{ns(el, :cac)}:Item") do |cel|
            maybe_find_one_text(cel, "#{ns(cel, :cbc)}:Description") do |text|
              o['description'] = text
            end
            maybe_find_code(cel, "#{ns(cel, :cac)}:CommodityClassification/#{ns(cel, :cbc)}:ItemClassificationCode") do |id|
              o['classification'] = id
            end
          end
          maybe_find_amount(el, "#{ns(el, :cbc)}:LineExtensionAmount") do |price|
            o['total_price'] = price
          end
          maybe_find_amount(el, "#{ns(el, :cac)}:ItemPriceExtension/#{ns(el, :cbc)}:Amount") do |price|
            o['price'] = price
          end
          maybe_find_quantity(el, "#{ns(el, :cbc)}:InvoicedQuantity") do |quantity|
            o['quantity'] = quantity
          end
          maybe_find_pricing(el, "#{ns(el, :cac)}:Price") do |pricing|
            o['pricing'] = pricing
          end
        end
      end
      
      def maybe_find_parties(el)
        parties_set = {
          'supplier' => "#{ns(el, :cac)}:AccountingSupplierParty/#{ns(el, :cac)}:Party",
          'customer' => "#{ns(el, :cac)}:AccountingCustomerParty/#{ns(el, :cac)}:Party",
          'payee'    => "#{ns(el, :cac)}:PayeeParty",
          'buyer'    => "#{ns(el, :cac)}:BuyerCustomerParty/#{ns(el, :cac)}:Party",
          'seller'   => "#{ns(el, :cac)}:SellerSupplierParty/#{ns(el, :cac)}:Party",
          'tax'      => "#{ns(el, :cac)}:TaxRepresentativeParty",
        }
        maybe_find_set(el, parties_set) do |vals|
          yield(vals.inject({}) do |parties, (k, el)|
                  parties.merge(k => extract_party(el))
                end)
        end
      end

      def maybe_find_identifier(pel, xp)
        maybe_find_one(pel, xp) do |el|
          yv = extract_identifier(el)
          yield(yv) if yv.any?
        end
      end

      def maybe_find_address(pel, xp)
        maybe_find_one(pel, xp) do |el|
          yield(extract_address(el))
        end
      end

      def maybe_find_location(pel, xp)
        maybe_find_one(pel, xp) do |el|
          yield(extract_location(el))
        end
      end

      def extract_code(el)
        # code has attrs:
        # languageID, listAgencyID, listAgencyName, listID, listName, listSchemeURI, listURI, listVersionID, listVersionID
        # and a value that should become:
        # { language_id, agency_ud, agency_name, list_id, list_name, scheme_uri, list_uri, version_id, name, value }
        {}.tap do |o|
          attrs_kmap = {
            'languageID'     => 'language_id',
            'listAgencyID'   => 'agency_id',
            'listAgencyName' => 'agency_name',
            'listID'         => 'list_id',
            'listName'       => 'list_name',
            'listSchemeURI'  => 'scheme_uri',
            'listURI'        => 'list_uri',
            'listVersionID'  => 'version_id',
            'name'           => 'name',
          }
          maybe_find_text_with_mapped_attrs(el, "#{ns(el, :cbc)}:ID", attrs_kmap) do |vals|
            o.merge!(vals)
          end
        end
      end

      def maybe_find_text_with_mapped_attrs(el, xp, attrs_kmap)
        maybe_find_one_text(el, xp, attrs_kmap.keys) do |text, vals|
          yield({ 'value' => text }.merge(transpose_keys(attrs_kmap, vals)))
        end        
      end
      
      def maybe_find_code(el, xp, &bl)
        # code has attrs:
        # languageID, listAgencyID, listAgencyName, listID, listName, listSchemeURI, listURI, listVersionID, listVersionID
        # and a value that should become:
        # { language_id, agency_ud, agency_name, list_id, list_name, scheme_uri, list_uri, version_id, name, value }
        attrs_kmap = {
          'languageID'     => 'language_id',
          'listAgencyID'   => 'agency_id',
          'listAgencyName' => 'agency_name',
          'listID'         => 'list_id',
          'listName'       => 'list_name',
          'listSchemeURI'  => 'scheme_uri',
          'listURI'        => 'list_uri',
          'listVersionID'  => 'version_id',
          'name'           => 'name',
        }
        maybe_find_text_with_mapped_attrs(el, xp, attrs_kmap, &bl)
      end

      def maybe_find_country(pel)
        maybe_find_one(pel, "#{ns(pel, :cac)}:Country") do |el|
          yield(extract_country(el))
        end
      end

      def maybe_find_subentity(el)
        yv = {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:CountrySubentity") do |text|
            o['name'] = text
          end
          maybe_find_code(el, "#{ns(el, :cbc)}:CountrySubentityCode") do |code|
            o['code'] = code
          end
        end
        yield(yv) if yv.any?
      end

      def maybe_find_amount(el, xp, &bl)
        attrs_kmap = {
          'currencyID' => 'currency_code',
        }
        
        maybe_find_text_with_mapped_attrs(el, xp, attrs_kmap, &bl)
      end

      def maybe_find_quantity(el, xp, &bl)
        attrs_kmap = {
          'unitCode' => 'unit',
        }
        
        maybe_find_text_with_mapped_attrs(el, xp, attrs_kmap, &bl)
      end

      def maybe_find_pricing(pel, xp)
        o = {}

        maybe_find_one(pel, xp) do |el|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:OrderableUnitFactorRate") do |text|
            o['orderable_factor'] = text
          end
          maybe_find_amount(el, "#{ns(el, :cbc)}:PriceAmount") do |price|
            o['price'] = price
          end
          maybe_find_quantity(el, "#{ns(el, :cbc)}:BaseQuantity") do |quantity|
            o['quantity'] = quantity
          end
        end
        
        yield(o) if o.any?
      end

      def extract_document_ids(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:ID") do |text|
            o['document_id'] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:UBLVersionID") do |text|
            o['version_id'] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:CustomizationID") do |text|
            o['customization_id'] = text
          end
        end
      end

      def extract_identifier(el)
        # identifier has attrs:
        # schemeAgencyID, schemeAgencyName, schemeDataURI, schemeVersionID, schemeID, schemeName, schemeURI
        # and a value that should become:
        # { agency_id, agency_name, data_uri, version_id, id, name, uri }
        {}.tap do |o|
          attrs_kmap = {
            'schemeAgencyID'   => 'agency_id',
            'schemeAgencyName' => 'agency_name',
            'schemeDataURI'    => 'data_uri',
            'schemeVersionID'  => 'version_id',
            'schemeID'         => 'id',
            'schemeURI'        => 'uri',
            'schemeName'       => 'name',
          }
          maybe_find_text_with_mapped_attrs(el, "#{ns(el, :cbc)}:ID", attrs_kmap) do |vals|
            o.merge!(vals)
          end
        end
      end

      def extract_party(el)
        {}.tap do |o|
          maybe_find_identifier(el, "#{ns(el, :cac)}:PartyIdentification") do |id|
            o['id'] = id
          end

          maybe_find_one_text(el, "#{ns(el, :cac)}:PartyName/#{ns(el, :cbc)}:Name") do |text|
            o['name'] = text
          end

          maybe_find_address(el, "#{ns(el, :cac)}:PostalAddress") do |address|
            o['address'] = address
          end

          maybe_find_location(el, "#{ns(el, :cac)}:PhysicalLocation") do |location|
            o['location'] = location
          end

          maybe_find_one(el, "#{ns(el, :cac)}:Person") do |el|
            o['person'] = extract_person(el)
          end

          maybe_find_one(el, "#{ns(el, :cac)}:Contact") do |el|
            o['contact'] = extract_contact(el)
          end

          maybe_find_code(el, "#{ns(el, :cbc)}:IndustryClassificationCode") do |code|
            o['industry'] = code
          end
        end
      end

      def extract_address(el)
        {}.tap do |o|
          maybe_find_code(el, "#{ns(el, :cbc)}:AddressFormatCode") do |code|
            o['format'] = code
          end

          address_list = [
            "#{ns(el, :cbc)}:StreetName",
            "#{ns(el, :cbc)}:AdditionalStreetName",
          ]
          maybe_find_list_text(el, address_list) do |texts|
            streets = texts.select { |t| !t.empty? }
            o['street'] = streets if streets.any?
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:BuildingNumber") do |text|
            o['number'] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:PostalZone") do |text|
            o['code'] = text
          end
          maybe_find_one_text(el, "#{ns(el, :cbc)}:CityName") do |text|
            o['city'] = text
          end

          maybe_find_subentity(el) do |e|
            o['subentity'] = e
          end

          maybe_find_country(el) do |country|
            o['country'] = country
          end
        end
      end

      def extract_location(el)
        {}.tap do |o|
          maybe_find_identifier(el, ".") do |id|
             o['id'] = id
          end
          maybe_find_address(el, "#{ns(el, :cac)}:Address") do |address|
            o['address'] = address
          end
        end
      end

      def extract_country(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |text|
            o['name'] = text
          end
          maybe_find_code(el, "#{ns(el, :cbc)}:IdentificationCode") do |code|
            o['code'] = code
          end
        end
      end

      def extract_person(el)
        {}.tap do |o|
          names_list = [
            "#{ns(el, :cbc)}:FirstName",
            "#{ns(el, :cbc)}:MiddleName",
            "#{ns(el, :cbc)}:OtherName",
          ]
          
          maybe_find_one_text(el, "#{ns(el, :cbc)}:FamilyName") do |text|
            o['surname'] = text
          end

          maybe_find_list_text(el, names_list) do |texts|
            names = texts.select { |t| !t.empty? }
            o['names'] = names if names.any?
          end
        end
      end

      def extract_contact(el)
        {}.tap do |o|
          maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |text|
            o['name'] = text
          end

          maybe_find_one_text(el, "#{ns(el, :cbc)}:Telephone") do |text|
            o['telephone'] = text
          end

          maybe_find_one_text(el, "#{ns(el, :cbc)}:ElectronicMail") do |text|
            o['email'] = text
          end

          maybe_find_identifier(el, '.') do |id|
            o['id'] = id
          end
        end
      end

      def transpose_keys(kmap, vals)
        vals.inject({}) do |o, (k, v)|
          kmap.key?(k) ? o.merge(kmap[k] => v) : o
        end
      end
    end
  end
end
