module XA
  module XML
    module Parse
      def load_and_parse_urn(urn, sym_root_xp, sym_make, &bl)
        load_and_parse(open(urn), sym_root_xp, sym_make, &bl)
      end

      def load_and_parse(b, sym_root_xp, sym_make, &bl)
        load(b) do |doc|
          begin
            maybe_find_one(doc, send(sym_root_xp, doc)) do |n|
              rv = send(sym_make, n)
              bl.call(rv) if rv && rv.any? && bl

              rv
            end
          rescue Nokogiri::XML::XPath::SyntaxError => e
            # nothing
          end
        end
      end

      def load(b)
        doc = Nokogiri::XML(b) do |cfg|
          cfg.noblanks.noent
        end
        yield(doc) if doc
      end
    end
  end
end
