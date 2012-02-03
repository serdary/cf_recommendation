module Recommendation  
  module RecommendModel
    # User-Based SVD (Model Based) Collaborative Filtering Method Implementation
    # Uses 'linalg' gem for matrix operations, please make sure it is working.
    # Takes first 2 columns of matrixes, finds user similarities using cosine
    # based similarity method, returns the list of recommended users
    # Use set_data method to initialize object with users and items
    # recommendations_for method for getting recommended items for active user
    # Read comments in class to get a better insight on inner helper methods
    class RecommendSVDUserBased < Recommendation::RecommendBase
      attr_accessor :users, :items, :default_recommendation_count, :default_similar_objects_count
      
      # Currently only cosine based similarity method is implemented.
      SIMILARITY_METHOD = 'cosine' # cosine
      MIN_SIMILARITY_PERCENTAGE = 0.9
      
      SAVE_COMPUTED_SVD_DATA = true
      USER_BASED_SVD_COMPUTED_DATA_FILE = File.dirname(__FILE__) + "/data/user_based_svd_data.dat"
      
      def initialize
        @file_path = USER_BASED_SVD_COMPUTED_DATA_FILE
        @save_data_to_file = SAVE_COMPUTED_SVD_DATA
      end
      
      def set_data(users, items)
        @users, @items = users, items
      end
      
      # Generates recommendations for active user
      def recommendations_for(active_user)
        recommend_by_user_based active_user
      end
      
      private
      
      # Takes the most similar user's items.
      # Creates a weighted sum for the all items by multiplying every item
      # (with TOP similar user similarity percentage)
      # Returns the recommendation list with estimated ratings.
      def recommend_by_user_based(active_user)
        return unless @similarity_matrix
        
        weighted_similar_items = Hash.new(0.0)
        similarity_sum_per_item = Hash.new(0.0)
        
        similar_users = @similarity_matrix[active_user.id]
        return unless similar_users
        
        most_similar_user = @users[similar_users[0][:id]]
        most_similar_user.list.items.each do |k, user_item|
          next if active_user.has_item? user_item.id
          
          similar_users.each do |obj|
            rating = @users[obj[:id]].rating_for user_item.id
            next if rating.nil? or rating < 1
            
            weighted_similar_items[user_item.id] += rating * obj[:similarity].abs
            similarity_sum_per_item[user_item.id] += obj[:similarity].abs
          end
        end
        
        recommendations = []
        weighted_similar_items.each do |k, v|
          next if v == 0.0 or similarity_sum_per_item[k] == 0.0
          est = v / similarity_sum_per_item[k]
          est = 5 if est > 5
          est = 1 if est < 1
          recommendations << { :id => k, :est => est }
        end
        recommendations.compact.sort{ |x, y| y[:est] <=> x[:est] }
      end
      
      # Predicts a rating for active user and item
      # Gets similar users to active user, calculates a weighted rating sum
      def rating_for(active_user, item)
        return unless @similarity_matrix
        
        similarity_sum = weighted_rating_sum = 0
        
        similar_users = @similarity_matrix[active_user.id]
        return unless similar_users
        
        similar_users.each do |obj|
          rating = @users[obj[:id]].rating_for item.id
          next if rating.nil?
          
          weighted_rating_sum += rating * obj[:similarity].abs
          similarity_sum += obj[:similarity].abs
        end
        
        return nil if weighted_rating_sum == 0 or similarity_sum == 0
        
        rating = weighted_rating_sum / similarity_sum
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        rating
      end
      
      ### USER BASED SVD CF HELPER METHODS ###
            
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
#j=0
        @users.each_value do |user|
          puts "Started creating similar user for:#{user}"
          @similarity_matrix[user.id] = find_similar_users user, @default_similar_objects_count
#j+=1;break if j == 6
        end
        
        puts "Creation of similarity matrix for users lasted: #{Time.now - start_time} seconds."
      end
      
      # Finds similar users to active_user
      # Returns all similar users or specified top number of users
      def find_similar_users(user, top = nil)
        # Create active user's ratings matrix
        active_user_ratings = create_matrix_for_user user
        
        # Find user point on the graph
        user_embedded = active_user_ratings * @u_2col * @s_2col.inverse

        # Calculate cosine-based similarity
        user_sim = {}
        @v_2col.rows.each_with_index do |x, index|
          sim = (user_embedded.transpose.dot(x.transpose)) / (x.norm * user_embedded.norm)
          user_sim[index] = (sim.nan? or sim.nil?) ? 0 : sim
        end
        
        similar_users = user_sim.delete_if{ |k, sim| sim < MIN_SIMILARITY_PERCENTAGE or k+1 == user.id}
          .sort{ |x, y| y[1] <=> x[1] }
          
        similar_users = similar_users.first(top || similar_users.size)
          .collect{ |ind, sim| { :id => ind + 1, :similarity => sim.round(5) } }

        similar_users.size < 1 ? nil : similar_users
      end
      
      # Creates ratings matrix
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
      
      # Creates matrix consists of user's all ratings
      def create_matrix_for_user(obj)
        ratings = []
        @items.each_value do |item|
          rating = obj.rating_for item.id
          ratings << (rating || 0)
        end
        Linalg::DMatrix[ratings]
      end
      ### / USER BASED SVD CF HELPER METHODS ###
    end
  end
end