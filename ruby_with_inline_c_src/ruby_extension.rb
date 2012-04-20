class Array

  def pretty
    self.inject(""){|final_s, x|
      final_s << x.to_s << ' '
    }
  end

  alias_method :to_s, :pretty

  def map_with_index!
    each_with_index do |e, idx| self[idx] = yield(e, idx); end
  end

  def map_with_index(&block)
    dup.map_with_index!(&block)
  end

  def component_add(another_array)
    raise "array must have the same dimension" unless self.size == another_array.size
    self.map_with_index do |x, index|
      x + another_array[index]
    end
  end

  def component_subtract(another_array)
    raise "array must have the same dimension" unless self.size == another_array.size
    self.map_with_index do |x, index|
      x - another_array[index]
    end
  end
  def divide_by_scalar(scalar)
    self.map do |x|
      x / scalar
    end
  end
  def multiply_by_scalar(scalar)
    self.map do |x|
      x * scalar
    end
  end
end

class String
  def each_char_with_index
    i = 0
    split(//).each do |c|
      yield c, i
      i += 1
    end
  end
end

module Enumerable
  def inject_with_index(injected)
    each_with_index{ |obj, index| injected = yield(injected, obj, index) }
    injected
  end
end

