module ActsAsHavingPosts

  module ClassMethods
    def  acts_as_having_posts(options = {})
      has_many :posts, { :class_name => 'Article', :foreign_key => 'parent_id', :source => :children, :conditions => [ 'articles.type != ?', 'RssFeed' ], :order => 'published_at DESC, id DESC' }.merge(options)

      attr_accessor :feed_attrs

      after_create do |blog|
        blog.children << RssFeed.new(:name => 'feed', :profile => blog.profile)
        blog.feed = blog.feed_attrs
      end

      settings_items :posts_per_page, :type => :integer, :default => 5

      self.send(:include, ActsAsHavingPosts)
    end
  end

  def has_posts?
    true
  end

  def feed
    self.children.find(:first, :conditions => {:type => 'RssFeed'})
  end

  def feed=(attrs)
    if attrs
      if self.feed
        attrs.each do |key, value|
          self.feed.send(key.to_s+'=', value)
        end
      else
        self.feed_attrs = attrs
      end
    end
    self.feed
  end

  def name=(value)
    self.set_name(value)
    self.slug = self.slug.blank? ? self.name.to_slug : self.slug.to_slug
  end

end

ActiveRecord::Base.extend(ActsAsHavingPosts::ClassMethods)
