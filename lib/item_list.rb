module Recommendation
  # Stores UserItem objects
  class ItemList
    attr_accessor :items
    
    def initialize(list)
      @items = list || {}
    end
    
    # Adds a new item to the list
    def add(item)
      @items[item.id] = item
    end
    
    # Returns an item from the list by id
    def find(id)
      @items[id]
    end
    
    # Checks if item included in list
    def has_item?(id)
      @items[id] != nil
    end
  
    def to_s
      "ItemList: #{@items.each { |i| print "#{i}," }}"
    end
  end
end