# A pseudo profile is a person from a remote network
class ExternalPerson < ActiveRecord::Base

  include Human
  include ProfileEntity

  validates_uniqueness_of :identifier, scope: :source

  attr_accessible :source, :email_md5_hash

  def self.get_or_create(webfinger)
    user = ExternalPerson.find_by(identifier: webfinger.identifier, source: webfinger.domain)
    if user.nil?
      user = ExternalPerson.create!(identifier: webfinger.identifier,
                                    name: webfinger.name,
                                    source: webfinger.domain,
                                    email_md5_hash: webfinger.email_md5
                                   )
    end
    user
  end

  def url
    "http://#{self.source}/#{self.identifier}"
  end

  def avatar
    "http://#{self.source}/plugin/gravatar_provider/h/#{self.email_md5_hash}"
  end

  def preferred_login_redirection
    environment.redirection_after_login
  end

end
