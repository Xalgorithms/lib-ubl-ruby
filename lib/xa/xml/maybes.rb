module XA
  module XML
    module Maybes
      def maybe_find_one(pn, xp, attrs = {}, &bl)
        rv = pn.xpath(xp).first
        attrs = attrs.inject({}) { |o, k| o.merge(k => rv[k]) } if rv
        rv = bl.call(rv, attrs) if rv && bl
        rv
      end

      def maybe_find_many(pn, xp, &bl)
        rv = pn.xpath(xp)
        rv = bl.call(rv) if rv && rv.any? && bl
        rv
      end

      def maybe_find_set(pn, xp_set, &bl)
        rv = xp_set.keys.inject({}) do |o, k|
          maybe_find_one(pn, xp_set[k]) do |n|
            o = o.merge(k => n)
          end

          o
        end
        rv = bl.call(rv) if rv.any? && bl
        rv
      end

      def maybe_find_set_text(pn, xp_set, &bl)
        rv = {}
        maybe_find_set(pn, xp_set) do |s|
          rv = s.inject({}) do |o, kv|
            o.merge(kv.first => kv.last.text)
          end
        end

        rv = bl.call(rv) if rv.any? && bl
        rv
      end
      
      def maybe_find_one_text(pn, xp, attrs = {}, &bl)
        maybe_find_one(pn, xp, attrs) do |n, attrs|
          rv = n.text
          rv = bl.call(rv, attrs) if bl
          rv
        end
      end

      def maybe_find_one_tagged_text(pn, xp, &bl)
        maybe_find_one(pn, xp, ['languageID']) do |n, attrs|
          rv = { text: n.text }.tap do |o|
            o[:language] = attrs['languageID'] if attrs['languageID']
          end
          rv = bl.call(rv) if bl
          rv
        end
      end

      def maybe_find_one_int(pn, xp, attrs = {}, &bl)
        maybe_find_one(pn, xp, attrs) do |n, attrs|
          rv = n.text.to_i
          rv = bl.call(rv, attrs) if bl
          rv
        end
      end

      def maybe_find_one_convert(sym, pn, xp, &bl)
        maybe_find_one(pn, xp) do |n|
          rv = send(sym, n)
          rv = bl.call(rv) if rv && rv.any? && bl
          rv
        end
      end

      def maybe_find_many_convert(sym, pn, xp, &bl)
        maybe_find_many(pn, xp) do |ns|
          rv = ns.map(&method(sym))
          rv = bl.call(rv) if rv && rv.any? && bl
          rv
        end
      end
    end
  end
end
