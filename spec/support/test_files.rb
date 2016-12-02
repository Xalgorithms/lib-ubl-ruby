require 'nokogiri'

module TestFiles
  def load_test_file(index)
    load_test_file_content(index) do |content|
      doc = Nokogiri::XML(content) do |cfg|
        cfg.noblanks.noent
      end
      yield(doc.root) if doc
    end
  end

  def load_test_file_content(index)
    yield(IO.read("spec/files/#{index}.xml"))
  end
end
