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
      

      def maybe_find_parties(el)
        parties_set = {
          'supplier' => "#{ns(el, :cac)}:AccountingSupplierParty/#{ns(el, :cac)}:Party",
          'customer' => "#{ns(el, :cac)}:AccountingCustomerParty/#{ns(el, :cac)}:Party",
          'payee'    => "#{ns(el, :cac)}:PayeeParty",
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
          maybe_find_one_text(el, "#{ns(el, :cbc)}:ID", attrs_kmap.keys) do |text, vals|
            o.merge!({ 'value' => text }.merge(transpose_keys(attrs_kmap, vals)))
          end
        end
      end
      
      def maybe_find_code(el, xp)
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
        maybe_find_one_text(el, xp, attrs_kmap.keys) do |text, vals|
          yield({ 'value' => text }.merge(transpose_keys(attrs_kmap, vals)))
        end
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
          maybe_find_one_text(el, "#{ns(el, :cbc)}:ID", attrs_kmap.keys) do |text, vals|
            o.merge!({ 'value' => text }.merge(transpose_keys(attrs_kmap, vals)))
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

    #   def maybe_find_period(el, &bl)
    #     period_set = {
    #       starts: "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:StartDate",
    #       ends:   "#{ns(el, :cac)}:InvoicePeriod/#{ns(el, :cbc)}:EndDate",
    #     }
        
    #     maybe_find_set_text(el, period_set) do |s|
    #       bl.call(s) if bl
    #     end
    #   end
      
    #   def maybe_find_parties(el, &bl)
    #     parties_set = {
    #       supplier: "#{ns(el, :cac)}:AccountingSupplierParty/#{ns(el, :cac)}:Party",
    #       customer: "#{ns(el, :cac)}:AccountingCustomerParty/#{ns(el, :cac)}:Party",
    #       payer:    "#{ns(el, :cac)}:PayeeParty",
    #     }
    #     maybe_find_set(el, parties_set) do |parties_els|
    #       parties = parties_els.inject({}) do |o, kv|
    #         o.merge(kv.first => make_party(kv.last))
    #       end
    #       bl.call(parties) if parties.any? && bl
    #     end
    #   end

    #   def maybe_find_id(el, xp = nil, &bl)
    #     lxp = [xp, "#{ns(el, :cbc)}:ID"].compact.join('/')
    #     maybe_find_one_convert(:make_id, el, lxp, &bl)
    #   end

    #   def make_id(el)
    #     {
    #       value: el.text,
    #     }.tap do |o|
    #       o[:scheme] = el['schemeID'] if el['schemeID']
    #       o[:agency] = el['schemeAgencyID'] if el['schemeAgencyID']
    #     end
    #   end
      
    #   def make_invoice(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:ID") do |text|
    #         o[:id] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:UBLVersionID") do |text|
    #         o[:version_id] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:CustomizationID") do |text|
    #         o[:customization_id] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:IssueDate") do |text|
    #         o[:issued] = { date: text }
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:IssueTime") do |text|
    #         o[:issued] = o.fetch(:issued, {}).merge(time: text)
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:DocumentCurrencyCode") do |text|
    #         o[:currency] = text
    #       end
          
    #       maybe_find_period(el) do |period|
    #         o[:period] = period
    #       end
          
    #       maybe_find_parties(el) do |parties|
    #         o[:parties] = parties
    #       end

    #       maybe_find_one_convert(:make_delivery, el, "#{ns(el, :cac)}:Delivery") do |co|
    #         o[:delivery] = co
    #       end

    #       # add PaymentMeans && PaymentTerms (needs looking at spec)
    #       maybe_find_many_convert(:make_line, el, "#{ns(el, :cac)}:InvoiceLine") do |lines|
    #         o[:lines] = lines
    #       end

    #       maybe_find_one_convert(:make_totals, el, "#{ns(el, :cac)}:LegalMonetaryTotal") do |totals|
    #         o[:totals] = totals
    #       end
    #     end
    #   end

    #   def maybe_find_scheme_id(el, xp, &bl)
    #     mapping = {
    #       id: 'schemeID',
    #       name: 'schemeName',
    #       uri: 'schemeURI',
    #     }
        
    #     maybe_find_one_text(el, xp, mapping.values) do |text, attrs|
    #       scheme = mapping.inject({}) do |o, (k, ak)|
    #         av = attrs.fetch(ak, nil)
    #         av ? o.merge(k => av) : o
    #       end
    #       id = { value: text }.tap do |o|
    #         o[:scheme] = scheme unless scheme.empty?
    #       end
          
    #       bl.call(id) if bl
    #     end
    #   end

    #   def make_location(el)
    #     rv = nil
    #     maybe_find_scheme_id(el, "#{ns(el, :cbc)}:ID") do |id|
    #       rv = { id: id }
    #     end
    #     maybe_find_one_convert(:make_address, el, "#{ns(el, :cac)}:Address") do |a|
    #       rv = (rv || {}).merge({ address: a })
    #     end
    #     rv
    #   end

    #   # DEBT: https://www.pivotaltracker.com/story/show/149463055
    #   # new version of make_address_deprecated - should become standard for all
    #   def make_address(el)
    #     {}.tap do |o|
    #       maybe_find_list_code(el, "#{ns(el, :cbc)}:AddressFormatCode") do |c|
    #         o[:format] = { code: c }
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:StreetName") do |text|
    #         o[:street] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:AdditionalStreetName") do |text|
    #         o[:street] = o.key?(:street) ? [o[:street], text] : text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:BuildingNumber") do |text|
    #         o[:number] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:PostalZone") do |text|
    #         o[:zone] = text
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:CityName") do |text|
    #         o[:city] = text
    #       end
    #       maybe_find_one_convert(:make_country, el, "#{ns(el, :cac)}:Country") do |c|
    #         o[:country] = c
    #       end
    #       maybe_find_list_code(el, "#{ns(el, :cbc)}:CountrySubentityCode") do |c|
    #         o[:subentity] = { code: c }
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:CountrySubentity") do |text|
    #         o[:subentity] = o.fetch(:subentity, {}).merge(name: text)
    #       end
    #     end
    #   end
      
    #   def make_country(el)
    #     {}.tap do |o|
    #       maybe_find_list_code(el, "#{ns(el, :cbc)}:IdentificationCode") do |c|
    #         o[:code] = c
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |text|
    #         o[:name] = text
    #       end
    #     end
    #   end

    #   def maybe_find_list_code(el, xp)
    #     attrs = [
    #       'listID', 'listName', 'listAgencyID', 'listAgencyName', 'listVersionID'
    #     ]
    #     maybe_find_one_text(el, xp, attrs) do |text, vals|
    #       code = { value: text }.tap do |o|
    #         o[:version] = vals['listVersionID'] if vals.key?('listVersionID')
    #         o[:list] = { id: vals['listID'] } if vals.key?('listID')
    #         o[:list] = o.fetch(:list, {}).merge({ name: vals['listName'] }) if vals.key?('listName')
    #         o[:agency] = { id: vals['listAgencyID'] } if vals.key?('listAgencyID')
    #         o[:agency] = o.fetch(:agency, {}).merge({ name: vals['listAgencyName'] }) if vals.key?('listAgencyName')
    #       end

    #       yield(code)
    #     end
    #   end

    #   def make_delivery(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:ActualDeliveryDate") do |text|
    #         o[:date] = text
    #       end
    #       maybe_find_one_convert(:make_address, el, "#{ns(el, :cac)}:DeliveryAddress") do |co|
    #         o[:address] = co
    #       end
    #       maybe_find_one_convert(:make_delivery_location, el, "#{ns(el, :cac)}:DeliveryLocation") do |co|
    #         o[:location] = co
    #       end
    #     end
    #   end

    #   def make_delivery_location(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |text|
    #         o[:name] = text
    #       end
    #       maybe_find_one_convert(:make_delivery_validity, el, "#{ns(el, :cac)}:ValidityPeriod") do |co|
    #         o[:validity] = co
    #       end          
    #       maybe_find_one_convert(:make_address, el, "#{ns(el, :cac)}:Address") do |co|
    #         o[:address] = co
    #       end
    #     end
    #   end

    #   def make_delivery_validity(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:StartDate") do |text|
    #         o[:starts] = text
    #       end          
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:EndDate") do |text|
    #         o[:ends] = text
    #       end
    #     end
    #   end
      
    #   # DEBT: https://www.pivotaltracker.com/story/show/149463055
      
    #   def make_party(party_el)
    #     # ignoring: cbc:EndpointID, cbc:ID
    #     {}.tap do |o|
    #       maybe_find_scheme_id(party_el, "#{ns(party_el, :cac)}:PartyIdentification/#{ns(party_el, :cbc)}:ID") do |id|
    #         o[:id] = id
    #       end
    #       maybe_find_one_text(party_el, "#{ns(party_el, :cac)}:PartyName/#{ns(party_el, :cbc)}:Name") do |text|
    #         o[:name] = text
    #       end
    #       maybe_find_one_convert(:make_address, party_el, "#{ns(party_el, :cac)}:PostalAddress") do |a|
    #         o[:address] = a
    #       end
    #       maybe_find_one_convert(:make_location, party_el, "#{ns(party_el, :cac)}:PhysicalLocation") do |loc|
    #         o[:location] = loc
    #       end
    #       maybe_find_one_convert(:make_legal, party_el, "#{ns(party_el, :cac)}:PartyLegalEntity") do |l|
    #         o[:legal] = l
    #       end
    #       maybe_find_one_convert(:make_contact, party_el, "#{ns(party_el, :cac)}:Contact") do |contact|
    #         o[:contact] = contact
    #       end
    #       maybe_find_one_convert(:make_person, party_el, "#{ns(party_el, :cac)}:Person") do |person|
    #         o[:person] = person
    #       end
    #       maybe_find_list_code(party_el, "#{ns(party_el, :cbc)}:IndustryClassificationCode") do |c|
    #         o[:industry_code] = c
    #       end
    #     end
    #   end
      
    #   def make_address_deprecated(n)
    #     {}.tap do |o|
    #       maybe_find_id(n) do |id|
    #         o[:id] = id
    #       end

    #       street_set = {
    #         name: "#{ns(n, :cbc)}:StreetName",
    #         unit: "#{ns(n, :cbc)}:AdditionalStreetName",
    #       }
    #       maybe_find_set_text(n, street_set) do |street|
    #         o[:street] = street
    #       end

    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:BuildingNumber") do |text|
    #         o[:number] = text
    #       end

    #       additional_set = {
    #         department: "#{ns(n, :cbc)}:Department",
    #       }
    #       maybe_find_set_text(n, additional_set) do |additional|
    #         o[:additional] = additional
    #       end
          
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:CountrySubentityCode") do |text|
    #         o[:region] = text
    #       end

    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:PostalZone") do |text|
    #         o[:zone] = text
    #       end
          
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:CityName") do |text|
    #         o[:city] = text
    #       end
    #       maybe_find_one_text(n, "#{ns(n, :cac)}:Country/#{ns(n, :cbc)}:IdentificationCode") do |text|
    #         o[:country_code] = text
    #       end
    #     end
    #   end

    #   def make_legal(n)
    #     # not handling cbc:CompanyID
    #     {}.tap do |o|
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:RegistrationName") do |text|
    #         o[:name] = text
    #       end
    #       maybe_find_one_convert(:make_address_deprecated, n, "#{ns(n, :cac)}:RegistrationAddress") do |a|
    #         o[:address] = a
    #       end
    #     end
    #   end

    #   def make_contact(n)
    #     {}.tap do |o|
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:Telephone") do |text|
    #         o[:telephone] = text
    #       end
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:Telefax") do |text|
    #         o[:fax] = text
    #       end
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:ElectronicMail") do |text|
    #         o[:email] = text
    #       end
    #     end
    #   end

    #   def make_person(n)
    #     @names_set ||= {
    #       first:  "#{ns(n, :cbc)}:FirstName",
    #       family: "#{ns(n, :cbc)}:FamilyName",
    #       other:  "#{ns(n, :cbc)}:OtherName",
    #       middle: "#{ns(n, :cbc)}:MiddleName",
    #     }
    #     {}.tap do |o|
    #       maybe_find_set_text(n, @names_set) do |names|
    #         o[:name] = names
    #       end
    #       maybe_find_one_text(n, "#{ns(n, :cbc)}:JobTitle") do |text|
    #         o[:title] = text
    #       end
    #     end
    #   end

    #   def make_line(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:ID") do |text|
    #         o[:id] = text
    #       end
    #       maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, :cbc)}:LineExtensionAmount") do |c|
    #         o[:price] = c
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:InvoicedQuantity", ['unitCode']) do |text, vals|
    #         o[:quantity] = { value: text.to_i }.tap do |o|
    #           code = vals.fetch('unitCode', nil)
    #           o[:code] = code if code
    #         end
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Note") do |text|
    #         o[:note] = text
    #       end

    #       maybe_find_one_convert(:make_line_item, el, "#{ns(el, :cac)}:Item") do |item|
    #         o[:item] = item
    #       end

    #       maybe_find_one_convert(:make_line_pricing, el, "#{ns(el, :cac)}:Price") do |pricing|
    #         o[:pricing] = pricing
    #       end

    #       maybe_find_one_text(el, "#{ns(el, :cac)}:Price/#{ns(el, :cbc)}:OrderableUnitFactorRate") do |text|
    #         o[:orderable_factor] = text.to_f
    #       end

    #       maybe_find_one_convert(:make_line_tax, el, "#{ns(el, :cac)}:TaxTotal") do |tax|
    #         o[:tax] = tax
    #       end
    #     end
    #   end

    #   def make_price_with_currency(el)
    #     cid = el['currencyID']
    #     { value: el.text.to_f }.tap do |o|
    #       o[:currency] = cid if cid
    #     end
    #   end
      
    #   def make_totals(el)
    #     {}.tap do |o|
    #       {
    #         total: { ns: :cbc, name: 'LineExtensionAmount' },
    #         tax_exclusive: { ns: :cbc, name: 'TaxExclusiveAmount' },
    #         tax_inclusive: { ns: :cbc, name: 'TaxInclusiveAmount' },
    #         allowance: { ns: :cbc, name: 'AllowanceTotalAmount' },
    #         charge: { ns: :cbc, name: 'ChargeTotalAmount' },
    #         prepaid: { ns: :cbc, name: 'PrepaidAmount' },
    #         rounding: { ns: :cbc, name: 'PayableRoundingAmount' },
    #         payable: { ns: :cbc, name: 'PayableAmount' }
    #       }.each do |k, v|
    #         maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, v[:ns])}:#{v[:name]}") do |cur|
    #           o[k] = cur
    #         end
    #       end
    #     end
    #   end
      
    #   def maybe_find_line_item_ids(el, &bl)
    #     @line_item_ids ||= {
    #       seller:   "#{ns(el, :cac)}:SellersItemIdentification",
    #       standard: "#{ns(el, :cac)}:StandardItemIdentification",
    #     }

    #     ids = @line_item_ids.inject({}) do |oids, kv|
    #       maybe_find_id(el, kv.last) do |id|
    #         oids = oids.merge(kv.first => id)
    #       end
          
    #       oids
    #     end
        
    #     bl.call(ids) if ids.any? && bl
    #   end

    #   def maybe_find_line_item_classifications(el, &bl)
    #     xp = "#{ns(el, :cac)}:CommodityClassification/#{ns(el, :cbc)}:ItemClassificationCode"
    #     maybe_find_many_convert(:make_classification, el, xp, &bl)
    #   end

    #   def make_classification(el)
    #     {
    #       value: el.text
    #     }.tap do |o|
    #       o[:agency] = el['listAgencyID'] if el['listAgencyID']
    #       o[:id] = el['listID'] if el['listID']
    #     end
    #   end

    #   def maybe_find_tax_category(el, &bl)
    #     maybe_find_one_convert(:make_tax_category, el, "#{ns(el, :cac)}:ClassifiedTaxCategory", &bl)
    #   end

    #   def make_tax_category(el)
    #     {}.tap do |o|
    #       maybe_find_id(el) do |id|
    #         o[:id] = id
    #       end
    #       maybe_find_one_int(el, "#{ns(el, :cbc)}:Percent") do |percent|
    #         o[:percent] = percent
    #       end
    #       maybe_find_id(el, "#{ns(el, :cac)}:TaxScheme") do |id|
    #         o[:scheme] = id
    #       end
    #     end
    #   end

    #   def make_item_property(el)
    #     {}.tap do |o|
    #       { k: 'Name', v: 'Value' }.each do |k, v|
    #         maybe_find_one_text(el, "#{ns(el, :cbc)}:#{v}") do |text|
    #           o[k] = text
    #         end
    #       end
    #     end
    #   end
      
    #   def make_line_item(el)
    #     {}.tap do |o|
    #       maybe_find_one_tagged_text(el, "#{ns(el, :cbc)}:Description") do |desc|
    #         o[:description] = desc
    #       end

    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |name|
    #         o[:name] = name
    #       end

    #       maybe_find_line_item_ids(el) do |ids|
    #         o[:ids] = ids
    #       end

    #       maybe_find_line_item_classifications(el) do |classifications|
    #         o[:classifications] = classifications
    #       end

    #       maybe_find_tax_category(el) do |category|
    #         o[:tax_category] = category
    #       end

    #       maybe_find_many_convert(:make_item_property, el, "#{ns(el, :cac)}:AdditionalItemProperty") do |props|
    #         o[:props] = props.inject({}) do |o, kv|
    #           o.merge(kv[:k] => kv[:v])
    #         end
    #       end
    #     end
    #   end

    #   def make_line_pricing(el)
    #     {}.tap do |o|
    #       maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, :cbc)}:PriceAmount") do |c|
    #         o[:price] = c
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:BaseQuantity", ['unitCode']) do |text, vals|
    #         o[:quantity] = { value: text.to_i }.tap do |o|
    #           code = vals.fetch('unitCode', nil)
    #           o[:code] = code if code
    #         end
    #       end
    #     end
    #   end

    #   def make_line_tax(el)
    #     {}.tap do |o|
    #       maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, :cbc)}:TaxAmount") do |c|
    #         o[:total] = c
    #       end
    #       o[:components] = maybe_find_many_convert(:make_tax_component, el, "#{ns(el, :cac)}:TaxSubtotal")
    #     end
    #   end

    #   def make_tax_component(el)
    #     {}.tap do |o|
    #       maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, :cbc)}:TaxAmount") do |c|
    #         o[:amount] = c
    #       end
    #       maybe_find_one_convert(:make_price_with_currency, el, "#{ns(el, :cbc)}:TaxableAmount") do |c|
    #         o[:taxable] = c
    #       end
    #       o[:categories] = maybe_find_many_convert(:make_tax_category, el, "#{ns(el, :cac)}:TaxCategory")
    #     end
    #   end

    #   def make_tax_scheme_id(text, vals)
    #     { value: text }.tap do |o|
    #       agency_id = vals.fetch('schemeAgencyID', nil)
    #       scheme_id = vals.fetch('schemeID', nil)
    #       version_id = vals.fetch('schemeVersionID', nil)
    #       o[:agency_id] = agency_id if agency_id
    #       o[:scheme_id] = scheme_id if scheme_id
    #       o[:version_id] = version_id if version_id
    #     end
    #   end
      
    #   def make_tax_category(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:ID", ['schemeAgencyID', 'schemeID', 'schemeVersionID']) do |text, vals|
    #         o[:id] = make_tax_scheme_id(text, vals)
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Percent") do |text|
    #         o[:percent] = text.to_f
    #       end
    #       maybe_find_one_convert(:make_tax_category_scheme, el, "#{ns(el, :cac)}:TaxScheme") do |s|
    #         o[:scheme] = s
    #       end
    #     end
    #   end

    #   def make_tax_category_scheme(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:ID", ['schemeAgencyID', 'schemeID', 'schemeVersionID']) do |text, vals|
    #         o[:id] = make_tax_scheme_id(text, vals)
    #       end          
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:Name") do |text|
    #         o[:name] = text
    #       end
    #       maybe_find_one_convert(:make_tax_jurisdiction, el, "#{ns(el, :cac)}:JurisdictionRegionAddress") do |juri|
    #         o[:jurisdiction] = juri
    #       end
    #     end
    #   end

    #   def make_tax_jurisdiction(el)
    #     {}.tap do |o|
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:AddressFormatCode", ['listAgencyID', 'listID', 'listVersionID']) do |text, vals|
    #         o[:format] = { value: text }.tap do |o|
    #           agency_id = vals.fetch('listAgencyID', nil)
    #           id = vals.fetch('listID', nil)
    #           version_id = vals.fetch('listVersionID', nil)
    #           o[:agency_id] = agency_id if agency_id
    #           o[:id] = id if id
    #           o[:version_id] = version_id if version_id
    #         end
    #       end
    #       maybe_find_one_text(el, "#{ns(el, :cbc)}:District") do |text|
    #         o[:district] = text
    #       end
    #     end
    #   end
    end
  end
end
