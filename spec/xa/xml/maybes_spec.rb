require 'xa/xml/maybes'

describe XA::XML::Maybes do
  include XA::XML::Maybes

  it 'should locate one child node' do
    expectations = {
      'aa' => 'a-aa0',
      'ac' => 'a-ac',
      'aa/aab' => 'a-aa0-aab',
      'aa/ac' => 'a-aa0-ac',
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, id|
        el = maybe_find_one(root_el, xp)

        expect(el).to_not be_nil
        expect(el[:id]).to eql(id)

        rv = maybe_find_one(root_el, xp) do |el|
          expect(el[:id]).to eql(id)
          el[:id]
        end

        expect(rv).to eql(id)
      end
    end
  end

  it 'should locate one child node and yield the text' do
    expectations = {
      'ab' => 'A-AB0',
      'ac' => 'A-AC',
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, text|
        t = maybe_find_one_text(root_el, xp)

        expect(t).to eql(text)
        ln = t.length

        rv = maybe_find_one_text(root_el, xp) do |ac|
          expect(ac).to eql(text)
          text.length
        end

        expect(rv).to eql(ln)
      end
    end
  end

  it 'should locate one child node and yield the text converted to number' do
    expectations = {
      'ad' => 1,
      'ae' => 1234,
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, i|
        n = maybe_find_one_int(root_el, xp)

        expect(n).to eql(i)
        sq = n * n

        rv = maybe_find_one_int(root_el, xp) do |ac|
          expect(ac).to eql(n)
          ac * ac
        end

        expect(rv).to eql(sq)
      end
    end
  end

  def convert_el(el)
    # convert to something which supplies :any?
    [el[:id]]
  end

  it 'should locate one child node and yield the conversion according to the function' do
    expectations = {
      'aa' => 'a-aa0',
      'ac' => 'a-ac',
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, id|
        ac_id = maybe_find_one_convert(:convert_el, root_el, xp)

        expect(ac_id).to eql([id])

        maybe_find_one_convert(:convert_el, root_el, xp) do |ac_id|
          expect(ac_id).to eql([id])
        end
      end
    end
  end

  def convert_empty(el)
    []
  end
  
  it 'should locate one child node and not yield the conversion if the conversion is empty' do
    expectations = {
      'aa' => 'a-aa0',
      'ac' => 'a-ac',
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, id|
        ac_id = maybe_find_one_convert(:convert_empty, root_el, xp)

        expect(ac_id).to eql([])

        called = false
        maybe_find_one_convert(:convert_empty, root_el, xp) do |ac_id|
          called = true
        end

        expect(called).to eql(false)
      end
    end
  end
  
  it 'should locate one child node with attributes' do
    expectations = {
      'aa' => { 'x' => 'aa-x', 'y' => 'aa-y' },
      'ac' => { 'x' => 'ac-x', 'y' => 'ac-y' },
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, ex_attrs|
        maybe_find_one(root_el, xp, ['x', 'y']) do |el, attrs|
          expect(attrs).to eql(ex_attrs)
        end
      end
    end
  end

  it 'should locate all matching children' do
    expectations = {
      'aa/aaa' => ['a-aa0-aaa0', 'a-aa0-aaa1'],
      'aa'     => ['a-aa0', 'a-aa1' ],
      'ab'     => ['a-ab0', 'a-ab1' ],
    }
    load_test_file(0) do |root_el|
      expectations.each do |xp, ids|
        els = maybe_find_many(root_el, xp)

        expect(els).to_not be_empty
        expect(els.map { |el| el[:id] }).to eql(ids)

        ln = els.length
        
        rv = maybe_find_many(root_el, xp) do |els|
          expect(els.map { |el| el[:id] }).to eql(ids)
          els.length
        end

        expect(rv).to eql(ln)
      end
    end
  end

  it 'should locate via a set of xpaths' do
    expectations = {
      'aa' =>     { k: 'k0', id: 'a-aa0', },
      'ac' =>     { k: 'k1', id: 'a-ac', },
      'aa/aab' => { k: 'k2', id: 'a-aa0-aab', },
      'aa/ac' =>  { k: 'k3', id: 'a-aa0-ac', },
    }

    load_test_file(0) do |root_el|
      set = expectations.keys.inject({}) do |s, xp|
        s.merge(expectations[xp][:k] => xp)
      end

      ex = expectations.keys.inject({}) do |s, xp|
        s.merge(expectations[xp][:k] => expectations[xp][:id])
      end

      el_set = maybe_find_set(root_el, set)
      ac = el_set.keys.inject({}) { |o, k| o.merge(k => el_set[k][:id]) }
      expect(ac).to eql(ex)

      maybe_find_set(root_el, set) do |el_set|
        expect(el_set).to_not be_empty

        ac = el_set.keys.inject({}) { |o, k| o.merge(k => el_set[k][:id]) }
        expect(ac).to eql(ex)
      end
    end
  end
end
