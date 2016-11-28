require 'xa/ubl/invoice'

describe XA::UBL::Invoice do
  include XA::UBL::Invoice

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

  let(:content) do
    {
      ubl1: IO.read('spec/files/1.xml'),
      ubl2: IO.read('spec/files/2.xml'),
      ubl3: IO.read('spec/files/3.xml'),
      ubl4: IO.read('spec/files/4.xml'),
    }
  end
  
  it 'should start parsing the document with make_invoice' do
    content.each do |k, b|
      pr = Parser.new
      expect(pr).to receive(:make_invoice) do |el|
        expect(el.name).to eql('Invoice')

        # make_invoice is expected to yield a hash
        {}
      end

      pr.parse(b)
    end
  end

  def with_expectations(expectations)
    expectations.each do |k, ex|
      parser = Parser.new
      parser.parse(content[k]) do |invoice|
        yield(invoice, ex)
      end
    end
  end
  
  it 'should read some simple fields from the content' do
    expectations = {
      ubl1: {
        id: '00012b_EA_TEST',
        issued: '2016-11-15',
        currency: 'CAD',
      },
      ubl2: {
        id: '00009',
        issued: '2016-10-25',
        currency: 'USD',
      },
      ubl3: {
        id: 'FENDER-111111',
        issued: '2016-01-02',
        currency: 'USD',
      },
      ubl4: {
        id: 'TOSL108',
        issued: '2009-12-15',
        currency: 'EUR',
      },
    }

    with_expectations(expectations) do |invoice, ex|
      ex.keys.each do |k|
        expect(invoice[k]).to eql(ex[k])
      end
    end
  end

  it 'should read periods from the content' do
    expectations = {
      ubl1: nil,
      ubl2: nil,
      ubl3: nil,
      ubl4: {
        starts: '2009-11-01',
        ends: '2009-11-30',
      },
    }

    with_expectations(expectations) do |invoice, ex|
      expect(invoice[:period]).to eql(ex)
    end    
  end

  it 'should read parties from the content' do
    expectations = {
      ubl1: {
        supplier: {
          id: "5a8bb5df-89fb-4360-8f7e-f711ec846204",
          name: "Xalgorithms Foundation",
          address: {
            street: {
              name: "Hines Road",
              unit: "Kanata"
            },
            number: "50",
            zone: "K2K 2M5",
            city: "Ottawa",
            country_code: "CA"
          },
          person: {
            name: {
              first: "Joseph",
              family: "Potvin"
            }
          }
        },
        customer: {
          id: "9a928370-7ad6-47fb-972a-78888c7be302",
          name: "strangeware",
          address: {
            street: {
              name:
                "Jardin Pvt"
            },
            number: "49",
            zone: "K1K2V8",
            city: "Ottawa",
            country_code: "CA"
          }
        }
      },
      ubl2: {
        supplier: {
          id: "5a8bb5df-89fb-4360-8f7e-f711ec846204",
          name: "Xalgorithms Foundation",
          address: {
            street: {
              name: "Hines Road",
              unit: "Kanata"
            },
            number: "50",
            zone: "K2K 2M5",
            city: "Ottawa",
            country_code: "CA"
          },
          person: {
            name: {
              first: "Joseph",
              family: "Potvin"
            }
          }
        },
        customer: {
          id: "9a928370-7ad6-47fb-972a-78888c7be302",
          name: "strangeware",
          address: {
            street: {
              name: "Jardin Pvt"
            },
            number: "49",
            zone: "K1K2V8",
            city: "Ottawa",
            country_code: "CA"
          }
        }
      },
    }

    with_expectations(expectations) do |invoice, ex|
      expect(invoice[:parties]).to eql(ex)
    end    
  end
end

