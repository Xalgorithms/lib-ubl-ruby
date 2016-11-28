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

  let(:parser) do
    Parser.new
  end
  
  let(:content) do
    {
      ubl1: IO.read('spec/files/1.xml'),
      ubl2: IO.read('spec/files/2.xml'),
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
    }

    expectations.each do |k, ex|
      parser.parse(content[k]) do |invoice|
        ex.keys.each do |ex_k|
          expect(invoice[ex_k]).to eql(ex[ex_k])
        end
      end
    end
  end
end

