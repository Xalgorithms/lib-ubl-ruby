# coding: utf-8
require 'multi_json'

require 'xa/ubl/invoice'
require 'radish/documents/core'
require 'radish/documents/reduce'

describe XA::UBL::Invoice do
  include XA::UBL::Invoice
  include Radish::Documents::Core
  include Radish::Documents::Reduce

  it 'should map namespaces to prefixes that appear in the XML' do
    b = '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:CAC="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" xmlns:CBC="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2" xmlns:CCP="urn:oasis:names:specification:ubl:schema:xsd:CoreComponentParameters-2" xmlns:CEC="urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2" xmlns:ns7="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:SDT="urn:oasis:names:specification:ubl:schema:xsd:SpecializedDatatypes-2" xmlns:UDT="urn:un:unece:uncefact:data:specification:UnqualifiedDataTypesSchemaModule:2"></Invoice>'

    expectations = {
      invoice: 'ns7',
      cac: 'CAC',
      cbc: 'CBC',
      ccp: 'CCP',
      cec: 'CEC',
      sdt: 'SDT',
      udt: 'UDT',
    }

    doc = Nokogiri::XML(b)
    expectations.each do |k, s|
      expect(ns(doc.root, k)).to eql(s)
    end
  end

  class Parser
    include XA::UBL::Invoice
  end

  it 'should quietly fail to parse non-UBL' do
    rv = Parser.new.parse(IO.read('spec/files/0.xml'))
    expect(rv).to be_nil
  end
  
  let(:content) do
    {
      ubl0: IO.read('spec/files/1.xml'),
      ubl1: IO.read('spec/files/2.xml'),
      ubl2: IO.read('spec/files/3.xml'),
      ubl3: IO.read('spec/files/4.xml'),
      ubl4: IO.read('spec/files/gas_tax_example.xml'),
    }
  end
  
  def with_expectations(expectations)
    expectations.each do |k, ex|
      parser = Parser.new
      called = false
      parser.parse(content[k]) do |invoice|
        yield(invoice, ex, k)
        called = true
      end

      expect(called).to be true
    end
  end

  def with_expectations_from_files(tag, &bl)
    exs = content.keys.inject({}) do |o, k|
      fn = "spec/files/expectations/#{k}.#{tag}.json"
      o.merge(k => MultiJson.decode(IO.read(fn)))
    end
    with_expectations(exs, &bl)
  end
  
  def with_expectations_match(expectations, k)
    with_expectations(expectations) do |invoice, ex|
      expect(invoice[k]).to eql(ex)
    end
  end

  describe 'should read envelope' do
    it 'and set document ids' do
      expectations = {
        ubl0: {
          'document_id' => '00012b_EA_TEST',
          'version_id' => '2.0',
          'customization_id' => 'urn:tradeshift.com:ubl-2.0-customizations:2010-06',
        },
        ubl1: {
          'document_id' => '00009',
          'version_id' => '2.0',
          'customization_id' => 'urn:tradeshift.com:ubl-2.0-customizations:2010-06',
        },
        ubl2: {
          'document_id' => 'FENDER-111111',
          'version_id' => '2.1',
        },
        ubl3: {
          'document_id' => 'TOSL108',
          'version_id' => '2.1',
        },
        ubl4: {
          'document_id' => '1234',
        },
      }
      with_expectations(expectations) do |invoice, ex|
        expect(get(invoice, 'envelope.document_ids', {})).to eql(ex)
      end
    end

    it 'and set supplied dates' do
      expectations = {
        ubl0: {
          'issued' => '2016-11-15T01:23:04-04:00',
        },
        ubl1: {
          'issued' => '2016-10-25',
        },
        ubl2: {
          'issued' => '2016-01-02T01:23:46-04:00',
        },
        ubl3: {
          'issued' => '2009-12-15',
          'period' => {
            'starts' => '2009-11-01',
            'ends' => '2009-11-30',
          },
        },
        ubl4: {
          'issued' => '2017-05-12',
        },
      }
      with_expectations(expectations) do |invoice, ex|
        expect(get(invoice, 'envelope.issued')).to eql(ex['issued'])
        expect(get(invoice, 'envelope.period')).to eql(ex['period'])
      end
    end

    it 'and set currency' do
      expectations = {
        ubl0: {
          'currency' => 'CAD',
        },
        ubl1: {
          'currency' => 'USD',
        },
        ubl2: {
          'currency' => 'USD',
        },
        ubl3: {
          'currency' => 'EUR',
        },
        ubl4: {
          'currency' => nil,
        },
      }
      with_expectations(expectations) do |invoice, ex|
        expect(get(invoice, 'envelope.currency')).to eql(ex['currency'])
      end
    end

    it 'and set parties' do
      with_expectations_from_files('parties') do |invoice, ex, k|
        expect(ex).to_not be_empty
        ex.each do |k, v|
          expect(get(invoice, "envelope.parties.#{k}")).to eql(v)
        end
      end
    end
  end

  it 'should parse line items' do
      with_expectations_from_files('items') do |invoice, ex, k|
        # check each item individually to make debugging easier
        p [:ubl, k]
        items = get(invoice, 'items', [])

        expect(items.length).to eql(ex.length)
        items.each_with_index do |it, i|
          expect(it).to eql(ex[i])
        end
      end
  end
  
  # it 'should read deliveries from the content' do
  #   expectations = {
  #     ubl1: {
  #       address: {
  #         format: {
  #           code: {
  #             value: '5',
  #             version: 'D08B',
  #             list: { id: 'UN/ECE 3477' },
  #             agency: { id: '6' },
  #           },
  #         },
  #         street: "Jardin Pvt",
  #         number: "49",
  #         zone: "K1K2V8",
  #         city: "Ottawa",
  #         country: {
  #           code: {
  #             value: 'CA',
  #           },
  #           name: "Canada",
  #         },
  #         subentity: {
  #           code: {
  #             value: "CA-ON",
  #           },
  #           name: "Ontario",
  #         },
  #       },
  #     },      
  #     ubl3: {
  #       date: '2016-01-12',
  #       location: {
  #         name: "Home",
  #         validity: {
  #           starts: '2017-07-29',
  #           ends: '2017-07-31',
  #         },
  #         address: {
  #           street: "Rue Metcalfe",
  #           number: "2044",
  #           zone: "H3A1X7",
  #           city: "Montréal",
  #           subentity: {
  #             name: "QC",
  #           },
  #           country: {
  #             code: {
  #               value: 'CA',
  #             },
  #           },
  #         },
  #       },
  #     },
  #     ubl4: {
  #       date: "2009-12-15",
  #       location: {
  #         address: {
  #           street: ["Deliverystreet", "Side door"],
  #           number: "12",
  #           zone: "523427",
  #           city: "DeliveryCity",
  #           subentity: {
  #             name: "RegionC",
  #           },
  #           country: {
  #             code: {
  #               value: "BE",
  #             },
  #           },
  #         },
  #       },
  #     },
  #   }

  #   with_expectations_match(expectations, :delivery)
  # end
end

