module Recommendation
  module RecommendMemory
    # Item-Based Memory Collaborative Filtering Method Implementation
    # Use set_data method to initialize object with users and items
    # recommendations_for method for getting recommended items for active user
    # find_top_similar_items method for finding most similar items to active item
    # Read comments in class to get a better insight on inner helper methods
    class RecommendItemBased < Recommendation::RecommendBase
      attr_accessor :users, :items, :default_recommendation_count, :default_similar_objects_count
      
      # Currently 2 methods are supported, Euclidean and Pearson Methods are
      # used to find similarities between items
      SIMILARITY_METHOD = 'euclidean' # euclidean OR pearson 
      MIN_SIMILARITY = 0.00001
      
      # Save computed data to a file to use faster in future
      SAVE_COMPUTED_ITEM_BASED_DATA = true
      ITEM_BASED_COMPUTED_DATA_FILE = File.dirname(__FILE__) + '/data/item_based_memory_data.dat'
      
      def initialize
        @file_path = ITEM_BASED_COMPUTED_DATA_FILE
        @save_data_to_file = SAVE_COMPUTED_ITEM_BASED_DATA
      end
      
      def set_data(users, items)
        @users, @items = users, items
      end
      
      # Find recommendations for the active user
      def recommendations_for(obj)
        recommend_by_item_based obj
      end
      
      # Calculates similarity points for the active item,
      # and returns top similar items array
      def find_top_similar_items(active_obj, top = nil)
        return unless active_obj
        
        similarities = []
        # an optimisation tweak, pre-fetch all users with the active item
        list = users_have_same_item active_obj
        @items.each_value do |obj|
          next if obj.id == active_obj.id # Skip the same object
          sim = similarity_for_items active_obj, obj, list
          next if sim < MIN_SIMILARITY
          similarities << { :id => obj.id, :similarity => sim }
        end
        similarities.sort{ |x, y| y[:similarity] <=> x[:similarity] }.first(top || similarities.size)
      end
      
      private
      
      # Used to calculate recommendation by Item-based CF method.
      # Takes all items that user rated, fetches all similar items for each user item
      # Adds to a weighted matrix, if the user has not already rated that item
      # Calculates the weighted value for each movie, return top movies
      def recommend_by_item_based(user, top = @default_recommendation_count)
        return unless @similarity_matrix
        
        weighted_similar_items = Hash.new(0.0)
        similarity_sum_per_item = Hash.new(0.0)
            
        user.list.items.each_value do |user_item|
          item = @items[user_item.id]
          
          sim_objs = @similarity_matrix[item.id]
          sim_objs.each do |obj|
            next if user.has_item? obj[:id]
            weighted_similar_items[obj[:id]] += user_item.rating * obj[:similarity].abs
            similarity_sum_per_item[obj[:id]] += obj[:similarity].abs
          end
        end
        
        recommendations = weighted_similar_items.collect do |k, v|
          next if v == 0.0 or similarity_sum_per_item[k] == 0.0
          { :id => k, :est => (v / similarity_sum_per_item[k]) }
        end
        recommendations.compact.sort{ |x, y| y[:est] <=> x[:est] }.first(top || recommendations.size)
      end
      
      # Predicts rating for an item for the active user
      # Calculates weighted rating sum of similar items
      def rating_for(active_user, item)
        return unless @similarity_matrix
        
        weighted_similar_items = similarity_sum = 0

        sim_objs = @similarity_matrix[item.id]
        sim_objs.each do |obj|
          active_user_rating = active_user.rating_for obj[:id]
          next unless active_user_rating
          weighted_similar_items += active_user_rating * obj[:similarity].abs
          similarity_sum += obj[:similarity].abs
        end
        
        return nil if weighted_similar_items == 0 or similarity_sum == 0
        
        rating = weighted_similar_items / similarity_sum
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        rating
      end
      
      ### ITEM BASED COLLABORATIVE FILTERING HELPER METHODS ###
      
      # Creates a matrix that stores each item's similar items.
      # This will extract information about the app's dataset, 
      # and we can use this as a model to make future predictions.
      # Takes Around 100 secs for 100K items, and around 4500 secs for 1M items
      def recompute_similarity_matrix
        start_time = Time.now
        puts "Creation of similarity matrix for items started at: #{start_time}."
        @similarity_matrix = {}
        @items.each_value do |item|
          puts "Started creating similar items for:#{item}"
          @similarity_matrix[item.id] = find_top_similar_items item, @default_similar_objects_count
        end
        
        puts "Creation of similarity matrix for items lasted: #{Time.now - start_time} seconds."
      end
      
      # Calls specified method to find similarity between two items
      # Uses passed list if any (used to gain perf. a little bit)
      def similarity_for_items(item1, item2, list = nil)
        # cache disabled
        # cached_sim = get_cached_similarity_for item1, item2
        # return cached_sim if cached_sim
        sim = 0.0
        case SIMILARITY_METHOD
          when 'euclidean'
            sim = similarity_by_euclidean_for_items item1, item2, list
          when 'pearson'
            sim = similarity_by_pearson_for_items item1, item2, list
          when 'jaccard'
            sim = similarity_by_jaccard_for_items item1, item2, list
        end
        sim.round(5)
        #set_similarity_cache_for item1, item2, sim
      end
      
      # Returns cached similarity for items
      def get_cached_similarity_for(item1, item2)
        @cached_similarities["#{item1}_#{item2}"] || @cached_similarities["#{item2}_#{item1}"]
      end
      
      # Sets similarity cache for 2 items
      def set_similarity_cache_for(item1, item2, sim)
        @cached_similarities["#{item1}_#{item2}"] = sim
      end
      
      # Find similarity value for 2 items.
      # First, finds common users who rated same items, then calculates 
      # the similarity by Euclidean
      def similarity_by_euclidean_for_items(item1, item2, list)
        common_users = find_common_users(item1, item2, list)
        
        result = 0.0
        return result if common_users.size < 1
        
        common_users.each do |u|
          result += (u.rating_for(item1.id) - u.rating_for(item2.id))**2
        end
        result = 1 / (1 + result)
        # result = 1 / (1 + Math.sqrt(result)) TODO: make tests to see the difference
      end
      
      # Find similarity value for 2 items.
      # First, finds common users who rated same items, then calculates 
      # the similarity by Pearson Correlation
      # Pearson Correlation will be between [-1, 1]
      def similarity_by_pearson_for_items(item1, item2, list)
        common_users = find_common_users(item1, item2, list)
        size = common_users.size
        
        return 0 if size < 1
        
        i1_sum_ratings = i2_sum_ratings = i1_sum_sq_ratings = i2_sum_sq_ratings = sum_of_products = 0.0
        common_users.each do |user|
          i1_rating = user.rating_for item1.id
          i2_rating = user.rating_for item2.id
          
          # Sum of all ratings by users
          i1_sum_ratings += i1_rating
          i2_sum_ratings += i2_rating
          
          # Sum of all squared ratings by users
          i1_sum_sq_ratings += i1_rating**2
          i2_sum_sq_ratings += i2_rating**2
          
          # Sum of product of the ratings that given to the same item
          sum_of_products += i1_rating * i2_rating
        end
    
        # Long lines of calculations, see http://davidmlane.com/hyperstat/A56626.html for formula.
        numerator = sum_of_products - ((i1_sum_ratings * i2_sum_ratings) / size)
        denominator = Math.sqrt((i1_sum_sq_ratings - (i1_sum_ratings**2) / size) * (i2_sum_sq_ratings - (i2_sum_ratings**2) / size))
        
        result = denominator == 0 ? 0 : (numerator / denominator)
        
        result = -1.0 if result < -1
        result = 1.0 if result > 1
        result
      end
      
      # Returns a list of users who rated a specified item
      def users_have_same_item(item)
        # TODO: .collect is slow? (for 100K dataset around 60secs.)
        #@users.collect { |k, u| u if u.has_item? item.id }.compact
        #@users.collect { |k, u| u if u.list.items[item.id] }.compact
        list = {}
        @users.each do |k, u|
          list[k] = u if u.has_item? item.id
        end
        list
      end
      
      # Finds common users for the items and returns an array contains user objects
      def find_common_users(item1, item2, list = @users)
        #list.collect { |u| u if u.has_item? item1.id and u.has_item? item2.id }.compact
        #list.collect { |u| u if u.list.items[item1.id] and u.list.items[item2.id] }.compact
        common = []
        list.each_value do |u|
          common << u if u.has_item? item1.id and u.has_item? item2.id
        end
        common
      end
      ### / ITEM BASED COLLABORATIVE FILTERING HELPER METHODS ###
    end
  end
end