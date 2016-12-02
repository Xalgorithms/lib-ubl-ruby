# coding: utf-8
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

  def with_expectations_match(expectations, k)
    with_expectations(expectations) do |invoice, ex|
      expect(invoice[k]).to eql(ex)
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

    with_expectations_match(expectations, :period)
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

    with_expectations_match(expectations, :parties)
  end

  it 'should read deliveries from the content' do
    expectations = {
      ubl3: {
        date: "2016-01-12",
        address: {
          street: {
            name: "Rue Metcalfe"
          },
          number: "2044",
          zone: "H3A1X7",
          city: "Montréal",
          country_code: "CA"
        }
      },
      ubl4: {
        date: "2009-12-15",
        address: {
          street: {
            name: "Deliverystreet",
            unit: "Side door"
          },
          number: "12",
          zone: "523427",
          city: "DeliveryCity",
          country_code: "BE"
        }
      },
    }

    with_expectations_match(expectations, :delivery)
  end

  it 'should read item lines from the content' do
    expectations = {
      ubl2: [
        {
          id: '1',
          price: { value: 500.0, currency: 'CAD' },
          quantity: { value: 100, code: 'EA' },
          item: {
            description: { text: "Services - test description field" },
            name: "Services - test description field",
            ids: {
              seller: { value: "1234", scheme: "GTIN", agency: "9" }
            },
          },
          pricing: {
            price: { value: 5.0, currency: 'CAD' },
            quantity: { value: 1, code: 'EA' },
          },
          orderable_factor: 1.0,
          tax: {
            total: { value: 65.0, currency: 'CAD' },
            components: [
              {
                amount: { value: 65.0, currency: 'CAD' },
                taxable: { value: 500.0, currency: 'CAD' },
                categories: [
                  {
                    id: { value: 'S', agency_id: '6', scheme_id: 'UN/ECE 5305', version_id: 'D08B', },
                    percent: 13.0,
                    scheme: {
                      id: { value: 'AAG', agency_id: '6', scheme_id: 'UN/ECE 5153 Subset', version_id: 'D08B', },
                      name: 'CA ON HST 13%',
                      jurisdiction: {
                        format: { agency_id: '6', id: 'UN/ECE 3477', version_id: 'D08B', value: '5' },
                        district: 'ON',
                      },
                    },
                  },
                ],
              },
            ],
          },
        },
      ],
      ubl3: [
        {
          id: '1',
          quantity: { value: 1, code: 'C62' },
          item: {
            description: {
              text: "Features include a maple neck with vintage-tint gloss finish, 9.5”-radius rosewood fingerboard with 22 medium jumbo frets and parchment dot inlays, tortoiseshell (Three-Color Sunburst and Olympic White models) and white-black-white pickguards (Candy Apple Red and Surf Green models), Jaguar single-coil pickups, circuit selector and tone circuit switches, pickup on/off switches, skirted black control knobs (lead circuit) and black disc knobs (rhythm circuit), vintage-style bridge and non-locking floating vibrato with vintage-style tremolo arm, vintage-style chrome tuners and chrome hardware.",
              language: "EN"
            },
            name: "VINTAGE MODIFIED JAGUAR",
            ids: {
              seller: { value: "0302000500" },
              standard: { value: "111111", scheme: "GTIN", agency: "9" },
            },
            classifications: [
              { value: "60131303", agency: "113", id: "UNSPSC" },
            ],
          },
          pricing: {
            price: { value: 600.0, currency: 'USD' },
            quantity: { value: 1, code: 'C62' },
          },
        },
      ],
    }

    with_expectations_match(expectations, :lines)
  end
end

