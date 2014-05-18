module Recommendation  
  module RecommendModel  
    class RecommendSVDIncremental < Recommendation::RecommendBase
      attr_accessor :users, :items
      
      FEATURE_INIT_VALUE    = 0.1
      FEATURE_NUM           = 10
      MIN_EPOCH_NUM         = 50
      MAX_EPOCH_NUM         = 100
      MIN_IMPROVEMENT       = 0.0001
      LEARNING_RATE         = 0.001
      K_VALUE               = 0.015
      
      def set_data(users, items)
        @users, @items, @ratings_cache = users, items, Hash.new(0.0)
        
        init_features
        calculate_features
      end
        
      def predict_rating_for(active_user, item)
        rating_for active_user, item
      end
      
      private
      
      def rating_for(user, item)
        rating = 1
        
        (1..FEATURE_NUM).each do |feat_ind|
          rating += @item_features[feat_ind][item.id] * @user_features[feat_ind][user.id]
          rating = 5 if rating > 5
          rating = 1 if rating < 1
        end
        rating
      end
      
      def calculate_features
        last_rmse = rmse = 2.0
        
        (1..FEATURE_NUM).each do |feat_ind|
          puts "Feature Calculation:#{feat_ind}"
          
          epoch_ind = 0
          while epoch_ind < MIN_EPOCH_NUM or rmse <= last_rmse - MIN_IMPROVEMENT
            last_rmse = rmse
            sq_error = 0
            
            rating_count = error = 0
            # Loop every rating
            @users.each_value do |user|
              user.list.items.each_value do |user_item|
                key = "#{user.id}_#{user_item.id}"          
                estimated_rating = estimate_rating(user.id, user_item.id, feat_ind, @ratings_cache[key], true)
                error = user_item.rating.to_f - estimated_rating
                sq_error += error**2
                
                uv = @user_features[feat_ind][user.id]
                iv = @item_features[feat_ind][user_item.id]
                
                @user_features[feat_ind][user.id] += LEARNING_RATE * (error * iv - (K_VALUE * uv))
                @item_features[feat_ind][user_item.id] += LEARNING_RATE * (error * uv - (K_VALUE * iv))
                
                rating_count += 1
              end
            end
            
            epoch_ind += 1
            rmse = Math.sqrt(sq_error / rating_count)
            break if epoch_ind > MAX_EPOCH_NUM
          end
          
          @users.each_value do |user|
            user.list.items.each_value do |user_item|
              key = "#{user.id}_#{user_item.id}"
              @ratings_cache[key] = estimate_rating(user.id, user_item.id, feat_ind, @ratings_cache[key])
            end
          end
        end
      end
      
      def estimate_rating(user_id, item_id, feat_ind, cache_val, b_trailing = false)
        rating = (cache_val != 0) ? cache_val : 1.0
        rating += @item_features[feat_ind][item_id] * @user_features[feat_ind][user_id]

        rating += (FEATURE_NUM - feat_ind - 1) * (FEATURE_INIT_VALUE**2)  if b_trailing
                
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        
        rating
      end
      
      def init_features
        @item_size, @user_size = @items.size, @users.size
        @item_features, @user_features = {}, {}
        
        (1..FEATURE_NUM).each do |ind|
          @item_features[ind], @user_features[ind] = {}, {}
          
          @items.each { |k, _| @item_features[ind][k] = FEATURE_INIT_VALUE }
          @users.each { |k, _| @user_features[ind][k] = FEATURE_INIT_VALUE }
        end
      end
    end
  end
end