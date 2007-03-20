class Category < ActiveRecord::Base
  has_and_belongs_to_many :posts
  has_and_belongs_to_many :special_posts, :class_name => "Post"
  has_and_belongs_to_many :other_posts, :class_name => "Post"
  
  def self.what_are_you
    'a category...'
  end
  
  has_many :categorizations
  has_many :authors, :through => :categorizations, :select => 'authors.*, categorizations.post_id'
end

class SpecialCategory < Category
  
  def self.what_are_you
    'a special category...'
  end  
  
end
