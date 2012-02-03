# A simple class to test CF algorithms using MovieLens 100K or 1M sample datasets
require './../lib/recommend_factory'

class RecommendTest
  # MEMORY_BASED or MODEL_BASED
  CF_METHOD_TYPE = Recommendation::MODEL_BASED
  # MEMORY_BASED: USER_BASED or ITEM_BASED // MODEL_BASED: SVD_ITEM_BASED or SVD_USER_BASED
  CF_ALGORITHM   = Recommendation::SVD_USER_BASED
  
  REGENERATE_ITEM_BASED_DATA = true
  REGENERATE_SVD_DATA        = true
  
  # 1M => data/ml-1m/   // 100K => data/ml-100k/
  ML_BASE_FOLDER         = "../lib/data/ml-100k/"
  # 1M => users.dat     // 100K => u.user
  ML_USERS_FILE          = "#{ML_BASE_FOLDER}u.user"
  # 1M => movies.dat    // 100K => u.item
  ML_MOVIES_FILE         = "#{ML_BASE_FOLDER}u.item"
  # 1M => ratings.dat   // 100K => u.data  // 100K TEST => ua.base
  ML_RATINGS_FILE        = "#{ML_BASE_FOLDER}ua.base"
  ML_TEST_COMPARE_FILE   = "#{ML_BASE_FOLDER}ua.test"
  # 1M => "::" // 100K => "|"
  ML_ITEM_SEPERATOR      = "|"
    
  # Runs the test.
  # Gets a new instance of the specified CF implementation (by using Recommendation::Factory.get)
  # To re-generate the models, set above (REGENERATE_ITEM_BASED_DATA and REGENERATE_SVD_DATA) constants to true
  # Otherwise system will use pre-computed models by loading from file system
  def run
    start_time = Time.now
    puts "MovieLens data started loading at: #{start_time}."
    load_data_from_movielens
    load_data_end_time = Time.now 
    puts "MovieLens data loaded in #{load_data_end_time - start_time} seconds."
    puts '**************************************************'
    
    puts "Total Users  : #{@users.size}"
    puts "Total Items  : #{@items.size}"
    puts "Total Ratings: #{@total_rating_count}"
    puts '**************************************************'

    puts "MovieLens recommendation started at: #{load_data_end_time} seconds."
    recsys = Recommendation::Factory.get CF_METHOD_TYPE, CF_ALGORITHM
    recsys.set_data @users, @items
    #recsys.default_similar_objects_count = 5
    
    if CF_ALGORITHM == Recommendation::ITEM_BASED
      recsys.precompute REGENERATE_ITEM_BASED_DATA
    elsif CF_ALGORITHM == Recommendation::SVD_USER_BASED or CF_ALGORITHM == Recommendation::SVD_ITEM_BASED
      recsys.precompute REGENERATE_SVD_DATA
    end

=begin
    puts "Top 2 users' recommendations ......"
    (1..2).each do |i|
      recs = recsys.recommendations_for @users[i]
      next unless recs
      print "Recommendations for #{@users[i].name} are: "
      recs.each { |r| puts "#{@items[r[:id]].name} - #{r[:est]}" }
      puts '*'*100
    end
=end
    
    recommendation_end_time = Time.now
    puts "MovieLens recommendation ended at: #{recommendation_end_time - load_data_end_time}."
    
    load_test_ratings
    puts "MovieLens test data comparison started at: #{recommendation_end_time} seconds."
    
    compare_movielens_test_results recsys
    
    puts "MovieLens test data comparison ended at: #{Time.now - recommendation_end_time} seconds."
  end
  
  private
  # Loads test ratings from ML_TEST_COMPARE_FILE to compare predictions and 
  # actual ratings for user-item-rating triples
  def load_test_ratings
    @ratings = {}
    File.open(ML_TEST_COMPARE_FILE).each do |line|
      vals = line.split(ML_ITEM_SEPERATOR)
      user_id, item_id, rating = vals[0].to_i, vals[1].to_i, vals[2].to_i

      next if user_id == 0 or item_id == 0 or rating == 0
      
      user = @users[user_id]
      item = @items[item_id]
      next if user.nil? or item.nil?
      
      @ratings[user.id] ||= []
      @ratings[user.id] << { :item_id => item.id, :rating => rating }
    end
  end
  
  # Compare ML test results.
  # Used Root Mean Square Error (RMSE) to find the error on estimations
  def compare_movielens_test_results(recommend)
    sq_sum_of_diff, item_count = 0.0, 0
    
    rating_ind = 0
    @ratings.each do |k, v|
      rating_ind += 1
      puts "index:#{rating_ind}"
      
      v.each do |rating_pair|
        item_id = rating_pair[:item_id]
        rating = rating_pair[:rating]
        
        prediction = recommend.predict_rating_for @users[k], @items[item_id]
        next unless prediction
        
        item_count += 1
        sq_sum_of_diff += (prediction - rating)**2
        
        puts "#{@items[item_id]} Original:#{rating}. Estimated:#{prediction}"
      end
    end
    result = Math.sqrt(sq_sum_of_diff / item_count)
    puts "ITEMCOUNT:#{item_count}"
    puts "RESULT   :#{result}"
  end
  
  # Loads triples (user-item-rating) from files
  def load_data_from_movielens
    load_users_from_movielens
    load_movies_from_movielens    
    load_ratings_from_movielens
  end
  
  # Loads user file and creates objects to use
  def load_users_from_movielens
    @users = {}
    File.open(ML_USERS_FILE).each do |line|
      id = line.split(ML_ITEM_SEPERATOR)[0].to_i
      @users[id] = Recommendation::User.new(id, "U-#{id}")
    end
  end
  
  # Loads movies (items) file and creates objects to use
  def load_movies_from_movielens
    @items = {}
    File.open(ML_MOVIES_FILE, :encoding=>"ASCII-8BIT").each do |line|
      id = line.split(ML_ITEM_SEPERATOR)[0].to_i
      title = line.split(ML_ITEM_SEPERATOR)[1]
      @items[id] = Recommendation::Item.new(id, title)
    end
  end
  
  # Loads ratings file and creates objects to use
  def load_ratings_from_movielens
    @total_rating_count = 0
    File.open(ML_RATINGS_FILE).each do |line|
      user_id = line.split(ML_ITEM_SEPERATOR)[0].to_i
      item_id = line.split(ML_ITEM_SEPERATOR)[1].to_i
      rating = line.split(ML_ITEM_SEPERATOR)[2].to_i
      next if user_id == 0 or item_id == 0 or rating == 0
      
      user = @users[user_id]
      item = @items[item_id]
      next if user.nil? or item.nil?
      
      @total_rating_count += 1
      user.list.add Recommendation::UserItem.new(item, rating)
    end
  end
  
  # Used to display a summary of users and their items.
  # Not suitable for large datasets, just use with dummy small user/items lists
  def display(type = 'all')
    puts '_'*100
    puts @items.inspect if type == 'all'
    puts '_'*100
    
    @users.each_value do |u|
      puts "#{u.name} items: "
      u.list.items.each_value do |user_item|
        puts "#{@items[user_item.id]}-#{user_item.rating}"
      end
      puts
    end
    puts '_'*100
  end
end