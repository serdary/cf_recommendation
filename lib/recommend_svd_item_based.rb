module Recommendation  
  module RecommendModel
    # Item-Based SVD (Model Based) Collaborative Filtering Method Implementation
    # Uses 'linalg' gem for matrix operations, please make sure it is working.
    # Takes first 2 columns of matrixes, finds similarities using cosine
    # based similarity method, returns the list of recommended items
    # Use set_data method to initialize object with users and items
    # recommendations_for method for getting recommended items for active user
    # Read comments in class to get a better insight on inner helper methods
    class RecommendSVDItemBased < Recommendation::RecommendBase
      attr_accessor :users, :items, :default_recommendation_count, :default_similar_objects_count
      
      # Currently only cosine based similarity method is supported
      SIMILARITY_METHOD = 'cosine' # cosine-based
      MIN_SIMILARITY_PERCENTAGE = 0.9
      
      SAVE_COMPUTED_SVD_DATA = true
      USER_BASED_SVD_COMPUTED_DATA_FILE = File.dirname(__FILE__) + "/data/item_based_svd_data.dat"
      
      def initialize
        @file_path = USER_BASED_SVD_COMPUTED_DATA_FILE
        @save_data_to_file = SAVE_COMPUTED_SVD_DATA
      end
      
      def set_data(users, items)
        @users, @items = users, items
      end
      
      # Returns recommendations for a user
      def recommendations_for(active_user)
        recommend_by_item_based active_user
      end
      
      private
      
      # Creates recommendations for active user by active similars of user's items
      def recommend_by_item_based(active_user)
        return unless @similarity_matrix
        
        weighted_similar_items = Hash.new(0.0)
        similarity_sum_per_item = Hash.new(0.0)
        
        active_user.list.items.each_value do |user_item|
          item = @items[user_item.id]
          
          sim_objs = @similarity_matrix[item.id]
          sim_objs.each do |obj|
            next if active_user.has_item? obj[:id]
            weighted_similar_items[obj[:id]] += user_item.rating * obj[:similarity].abs
            similarity_sum_per_item[obj[:id]] += obj[:similarity].abs
          end
        end
        
        recommendations = weighted_similar_items.collect do |k, v|
          next if v == 0.0 or similarity_sum_per_item[k] == 0.0
          { :id => k, :est => (v / similarity_sum_per_item[k]) }
        end
        recommendations.compact.sort{ |x, y| y[:est] <=> x[:est] }.first(800)
      end
      
      # Creates a prediction for active user item
      def rating_for(active_user, item)
        return unless @similarity_matrix
        
        weighted_similar_items = similarity_sum = 0

        sim_objs = @similarity_matrix[item.id]
        return if sim_objs.nil?
        
        sim_objs.each do |obj|
          active_user_rating = active_user.rating_for obj[:id]
          next unless active_user_rating
          weighted_similar_items += active_user_rating * obj[:similarity].abs
          similarity_sum += obj[:similarity].abs
        end
        
        return if weighted_similar_items == 0 or similarity_sum == 0
        
        rating = weighted_similar_items / similarity_sum
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        rating
      end
      
      ### ITEM BASED SVD CF HELPER METHODS ###
      
      # Recomputes the similarity matrix
      def recompute_similarity_matrix
        start_time = Time.now
        puts "Creation of similarity matrix for users started at: #{start_time}."
        
        create_ratings_matrix
        # Apply SVD to matrix, get left, right and singular matrixes
        u, s, v = @matrix.singular_value_decomposition
        vt = v.transpose
        # Dimensionality Reduction:
        # Take first 2 columns from matrixes to represent on a graph by x and y 
        @u_2col = Linalg::DMatrix.join_columns [u.column(0), u.column(1)]
        @v_2col = Linalg::DMatrix.join_columns [vt.column(0), vt.column(1)]
        @s_2col = Linalg::DMatrix.columns [s.column(0).to_a.flatten[0,2], s.column(1).to_a.flatten[0,2]]
        @similarity_matrix = {}
        @items.each_value do |item|
          puts "Started creating similar item for:#{item}"
          @similarity_matrix[item.id] = find_similar_items item, @default_similar_objects_count
        end
        
        puts "Creation of similarity matrix for items lasted: #{Time.now - start_time} seconds."
      end
      
      # Find similar items to the active item
      def find_similar_items(item, top = nil)
        # Create active user's ratings matrix
        active_item_users = create_matrix_for_item item
        
        # Find item point on the graph
        item_embedded = active_item_users * @v_2col * @s_2col.inverse

        # Calculate cosine-based similarity
        item_sim = {}
        @u_2col.rows.each_with_index do |x, index|
          sim = (item_embedded.transpose.dot(x.transpose)) / (x.norm * item_embedded.norm)
          item_sim[index] = (sim.nan? or sim.nil?) ? 0 : sim
        end
        
        similar_items = item_sim.delete_if{ |k, sim| sim < MIN_SIMILARITY_PERCENTAGE or k+1 == item.id}
          .sort{ |x, y| y[1] <=> x[1] }
          
        similar_items = similar_items.first(top || similar_items.size)
          .collect{ |ind, sim| { :id => ind + 1, :similarity => sim.round(5) } }

        similar_items.size < 1 ? nil : similar_items
      end
      
      # Creates ratings matrix includes all ratings in system
      def create_ratings_matrix(obj = nil)
        ratings = []
        @items.each_value do |item|
          tmp = []
          @users.each_value do |user|
            next if (obj != nil and user.id == obj.id)
            
            rating = user.rating_for item.id
            tmp << (rating || 0)
          end
          ratings << tmp
        end
        @matrix = Linalg::DMatrix.rows(ratings)
      end
      
      # Creates matrix for the active user's items
      def create_matrix_for_item(obj)
        ratings = []
        @users.each_value do |user|
          rating = user.rating_for obj.id
          ratings << (rating || 0)
        end
        a=Linalg::DMatrix[ratings]
      end
      ### / USER BASED SVD CF HELPER METHODS ###
    end
  end
end