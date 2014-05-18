module Recommendation
  # A user-rating object that stores a rating user gave for a specific item
  class UserItem
    attr_reader :id, :rating
    
    def initialize(item, rating)
      @id, @rating = item.id, rating
    end
    
    def to_s
      "UserItem:#{@id},R:#{@rating}"
    end
  end
end