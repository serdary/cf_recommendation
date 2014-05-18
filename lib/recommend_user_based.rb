module Recommendation  
  module RecommendMemory
    # User-Based Memory Collaborative Filtering Method Implementation
    # Use set_data method to initialize object with users and items
    # recommendations_for method for getting recommended items for active user
    # find_top_similar_users method for finding most similar users to active user
    # Read comments in class to get a better insight on inner helper methods
    class RecommendUserBased < Recommendation::RecommendBase
      attr_accessor :users, :items, :default_recommendation_count, :default_similar_objects_count
            
      # Currently 3 methods are supported, Euclidean, Pearson and Jaccard Index
      # TODO: Recommendations are not acceptable when users' item list sizes are too different
      # but that is not took into account while calculating similarities 
      # by euclidean or pearson methods.
      SIMILARITY_METHOD = 'pearson' # euclidean OR pearson OR jaccard
      MIN_SIMILARITY = 0.00001
      
      def set_data(users, items)
        @users, @items = users, items
      end
      
      # Returns a recommendations list for the active user
      def recommendations_for(obj)
        recommend_by_user_based obj
      end
      
      # Calculates "item similarity percentage" between the active user and
      # all other users, and returns top similar users
      def find_top_similar_users(active_obj, top = nil)
        return unless active_obj
        
        similarities = []
        @users.each_value do |obj|
          next if obj.id == active_obj.id # Skip the same object
          sim = similarity_for_users active_obj, obj
          next if sim < MIN_SIMILARITY
          similarities << { :id => obj.id, :similarity => sim }
        end
    
        similarities.sort{ |x, y| y[:similarity] <=> x[:similarity] }.first(top || similarities.size)
      end
      
      private
      
      # Used to calculate recommendation by User-based CF method. (Neighborhood Based)
      # Find recommended items for the user
      def recommend_by_user_based(user, top = @default_recommendation_count)
        # This process will take so much time in a large dataset.
        # One way to solve this problem is using kNN, k Nearest Neighbors
        # While calculating the similar users for the action user, the top "k"
        # similar users can be stored and the weighted rating can be stored by
        # these top "k" users.
        
        # loop all users except the active user
        # take all items that are not rated by active user
        # calculate a sum value of weighted ratings
        similarity_sum = Hash.new(0)
        weighted_rating_sum = Hash.new(0)
        
        @users.each_value do |u|
          next if u.id == user.id
          
          sim = similarity_for_users user, u
          next if sim <= 0
          
          u.list.items.each_value do |item|
            next if user.has_item? item.id
            
            rating = u.rating_for(item.id)
            next if rating.nil?
            
            similarity_sum[item.id] += sim
            weighted_rating_sum[item.id] += sim * rating
          end
        end
        
        recommendations = weighted_rating_sum.collect do |k, v|
            next if v == 0.0 or similarity_sum[k] == 0.0
            { :id => k, :est => (v / similarity_sum[k]) }
          end
        
        recommendations.compact.sort{ |x, y| y[:est] <=> x[:est] }.first(top || recommendations.size)
      end
      
      # Predicts rating for the item
      def rating_for(active_user, item)        
        similarity_sum = weighted_rating_sum = 0
        
        @users.each_value do |u|          
          sim = similarity_for_users active_user, u
          rating = u.rating_for(item.id)
          next if sim <= 0 or rating.nil?
          
          weighted_rating_sum += sim * rating
          similarity_sum += sim
        end
        
        return nil if weighted_rating_sum == 0 or similarity_sum == 0
        
        rating = weighted_rating_sum / similarity_sum
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        rating
      end
      
      ### USER BASED COLLABORATIVE FILTERING HELPER METHODS ###
      
      # Find Similarities for the active user
      # Calls appropriate similarity method; Euclidean, Pearson Correlation or
      # Jaccard Index
      def similarity_for_users(u1, u2)
        sim = 0.0
        case SIMILARITY_METHOD
          when 'euclidean'
            sim = similarity_by_euclidean_for_users u1, u2
          when 'pearson'
            sim = similarity_by_pearson_for_users u1, u2
          when 'jaccard'
            sim = similarity_by_jaccard_for_users u1, u2
        end
        sim.round(5)
      end
      
      # Find Similarities for user by using euclidean.
      # Takes all common ratings that given by 2 users.
      # Calculates the square of the difference of ratings for the item
      # Returns the result that is divided to 1, which gives a result between 0-1
      def similarity_by_euclidean_for_users(u1, u2)
        common_items = find_common_items(u1, u2)
        
        result = 0.0
        return result if common_items.size < 1
        common_items.each do |id|
          result += (u1.rating_for(id) - u2.rating_for(id))**2
        end
        # TODO: Think about following: commons: user1: item1-R:1, user2: item1-R:5, SIM: 20%
        # commons: user1: item1-R:1,item2-R:1,item3-R:1, user2: item1-R:1,item2-R:1,item3-R:5, SIM: 20%
        # Adding 1 and inverting doesn't make so much sense!
        1 / (1 + result)
      end
      
      # Find Similarities for user by using Pearson Correlation.
      def similarity_by_pearson_for_users(u1, u2)
        common_items = find_common_items(u1, u2)
        size = common_items.size
        
        return 0 if size < 1
        
        u1_sum_ratings = u2_sum_ratings = u1_sum_sq_ratings = u2_sum_sq_ratings = sum_of_products = 0.0
        common_items.each do |id|
          u1_rating = u1.rating_for id
          u2_rating = u2.rating_for id
          
          # Sum of all ratings by users
          u1_sum_ratings += u1_rating
          u2_sum_ratings += u2_rating
          
          # Sum of all squared ratings by users
          u1_sum_sq_ratings += u1_rating**2
          u2_sum_sq_ratings += u2_rating**2
          
          # Sum of product of the ratings that given to the same item
          sum_of_products += u1_rating * u2_rating
        end
    
        # Long lines of calculations, see http://davidmlane.com/hyperstat/A56626.html for formula.
        numerator = sum_of_products - ((u1_sum_ratings * u2_sum_ratings) / size)
        denominator = Math.sqrt((u1_sum_sq_ratings - ((u1_sum_ratings**2) / size)) * (u2_sum_sq_ratings - ((u2_sum_ratings**2) / size)))
        result = denominator == 0 ? 0 : (numerator / denominator)
        
        result = -1.0 if result < -1
        result = 1.0 if result > 1
        result
      end
      
      # Find Similarities for user by using Jaccard Coefficient.
      # Divide common item size to all item size for 2 users
      # Multiply by the rating difference
      def similarity_by_jaccard_for_users(u1, u2)
        common_items = find_common_items(u1, u2)
        size = common_items.size
        return 0 if size < 1
        
        # Beside classic Jaccard index, a similarity weight is also considered.
        # Let's say user1 and user2 has 10 items common, so there will be max 40 ratings difference (10*(5-1)).
        # So every difference unit will affect the similarity as 2.5 percentage
        # Sum all difference points, multiply by unit_percentage and divide to 100 (to get a value between 0-1)
        # Subtract this value from classic Jaccard Index.
        total_diff = 0
        unit_percentage = 100.0 / (size * (5-1))
        common_items.each do |id|
          total_diff += (u1.rating_for(id) - u2.rating_for(id)).abs
        end
        diff_percentage = total_diff == 0 ? 0 : (total_diff * unit_percentage / 100)
        
        sim = (size.to_f / (u1.list.items.size + u2.list.items.size - size)) - diff_percentage
        sim > 0 ? sim : 0
      end
      
      def find_common_items(u1, u2)
        u1.list.items.collect { |k, u_item| u_item.id if u2.has_item? u_item.id }.compact
      end
      
      ###  / USER BASED COLLABORATIVE FILTERING HELPER METHODS ###
    end
  end
end