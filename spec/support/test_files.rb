require 'nokogiri'

module TestFiles
  def load_test_file(index)
    doc = Nokogiri::XML(IO.read("spec/files/#{index}.xml")) do |cfg|
      cfg.noblanks.noent
    end
    yield(doc.root) if doc
  end
end
