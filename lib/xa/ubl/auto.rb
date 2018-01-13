require 'active_support/core_ext/module'
require_relative './invoice'

module XA
  module UBL
    class Auto
      TYPES = [
        Invoice,
      ].inject({}) do |o, mod|
        inst = Class.new do
          include mod
        end.new
        o.merge(mod.name.demodulize.downcase => inst)
      end
      
      def self.parse(t, path, &bl)
        inst = TYPES.fetch(t.to_s)
        bl.call(inst.parse(IO.read(path))) if bl && inst
      end
    end
  end
end
