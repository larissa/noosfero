# A pseudo profile is a person from a remote network
class ExternalPerson < ActiveRecord::Base

  include Human
  include ProfileEntity

  validates_uniqueness_of :identifier, scope: :source

  attr_accessible :source, :email, :created_at

  def self.get_or_create(webfinger)
    user = ExternalPerson.find_by(identifier: webfinger.identifier, source: webfinger.domain)
    if user.nil?
      user = ExternalPerson.create!(identifier: webfinger.identifier,
                                    name: webfinger.name,
                                    source: webfinger.domain,
                                    email: webfinger.email,
                                    created_at: webfinger.created_at
                                   )
    end
    user
  end

  def url
    "http://#{self.source}/#{self.identifier}"
  end

  alias :public_profile_url :url

  def avatar
    "http://#{self.source}/plugin/gravatar_provider/h/#{Digest::MD5.hexdigest(self.email)}"
  end

  def admin_url
    "http://#{self.source}/myprofile/#{self.identifier}"
  end

  def profile_custom_icon(gravatar_default=nil)
    self.avatar
  end

  def preferred_login_redirection
    environment.redirection_after_login
  end

  def person?
    true
  end

  def is_admin?(environment = nil)
    false
  end

  def lat
    nil
  end
  def lng
    nil
  end

  def role_assignments
    RoleAssignment.none
  end

  def favorite_enterprises
    Enterprise.none
  end

  def memberships
    Profile.none
  end

  def friendships
    Profile.none
  end

  def follows?(profile)
    false
  end

  def is_a_friend?(person)
    false
  end

  def already_request_friendship?(person)
    false
  end

  class ExternalPerson::Image
    attr_accessor :path
    def initialize(path)
      self.path = path
    end
    def public_filename(size = nil)
      self.path
    end

    def content_type
      'image/png'
    end
  end

  def image
    ExternalPerson::Image.new(avatar)
  end

end
