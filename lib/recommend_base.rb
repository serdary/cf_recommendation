module Recommendation
  # Parent class for Collaborative Filtering Implementations.
  # Provides methods to save or load similarity matrixes to/from files.
  # These save/load methods are used especially while testing the algorithms
  # to speed up the building model process. In a production app, creating files 
  # and loading from files might not be a good idea.
  # Call 'precompute' method to create the similarity matrix from existing file 
  # or by re-computing
  class RecommendBase
    attr_accessor :similarity_matrix, :file_path, :save_data_to_file
    
    # Returns active user's prediction for the specified item
    # Calls rating_for method of the child class to compute the rating
    def predict_rating_for(active_user, item)
      # If active user is already rated that item, return the rating
      return active_user.rating_for item.id if active_user.has_item? item.id
        
      rating_for active_user, item
    end
      
    # Creates similarity matrix to use on predictions or recommendations
    # Re-creates the matrix or loads from file according to the recompute parameter
    def precompute(recompute = true)
      recompute ? recompute_data : load_data
    end
    
    # Recomputes the similarity matrix by calling recompute_similarity_matrix 
    # method of the child class
    def recompute_data
      recompute_similarity_matrix
      
      save_data if save_data_to_file
    end
    
    # Loads data from file to create similarity matrix
    def load_data
      return if @file_path.nil? or @file_path == ''
      @similarity_matrix, last_id = {}, 0
      File.open(@file_path).each do |line|
        values = line.split("|")
        if values.size == 1
          last_id = values[0].to_i
          @similarity_matrix[last_id] = []
        else
          @similarity_matrix[last_id] << { :id => values[0].to_i, :similarity => values[1].to_f }
        end
      end
    end
    
    # Saves similarity matrix data to the file
    # file_path property should be specified before calling this method
    def save_data
      return if @file_path.nil? or @file_path == ''
      
      start_time = Time.now
      puts "Saving computed data to file: #{@file_path} started at: #{start_time}."
      
      File.open(@file_path, 'w') do |f|
        @similarity_matrix.each do |k, v|
          f.puts k
          next if v.nil?
          v.each { |sim_pair| f.puts "#{sim_pair[:id]}|#{sim_pair[:similarity]}" }
        end
      end
      puts "Saving computed data to file: #{@file_path} ended at: #{Time.now - start_time}."
    end
  end
end