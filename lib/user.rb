module Recommendation
  # Stores user id, name attributes and an item_list object that holds all items user rated.
  class User
    attr_accessor :list
    attr_reader :id, :name
    
    # Initializes a new user with id, name and list of items
    def initialize(id, name, list = {})
      @id, @name = id, name
      @list = Recommendation::ItemList.new(list)
    end
    
    # Returns the item if user has rated that item
    def has_item?(id)
      @list.has_item? id
    end
    
    # Returns the rating of the item if user rated
    def rating_for(id)
      item = @list.find id
      item.rating if item
    end
    
    def to_s
      "User(#{@id}): #{@name}"
    end
  end
end