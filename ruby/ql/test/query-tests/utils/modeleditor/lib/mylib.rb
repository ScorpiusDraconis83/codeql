require_relative "./other"

class A
  def initialize(x, y)
  end

  def foo(x, y, key1:, **kwargs, &block)
  end

  def bar(x, *args)
  end

  def self.self_foo(x, y)
  end

  private

  def private_1(x, y)
  end

  class ANested
    def foo(x, y)
    end

    private

    def private_2(x, y)
    end
  end
end
