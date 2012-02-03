module Recommendation
  # Stores id and name attributes for item
  class Item
    attr_reader :id, :name
    
    def initialize(id, name)
      @id, @name = id, name
    end
    
    def to_s
      "#{@id}-#{@name}"
    end
  end
end