module ProfileEntity
  extend ActiveSupport::Concern

  included do
    attr_accessible :name, :identifier, :environment, :redirection_after_login

    validates_presence_of :identifier, :name
    validates_inclusion_of :redirection_after_login, :in => Environment.login_redirection_options.keys, :allow_nil => true

    belongs_to :environment
    has_many :search_terms, :as => :context
    has_many :abuse_complaints, :foreign_key => 'requestor_id', :dependent => :destroy

  end

  def disable
    self.visible = false
    self.save
  end

  def enable
    self.visible = true
    self.save
  end

  def preferred_login_redirection
    redirection_after_login.blank? ? environment.redirection_after_login : redirection_after_login
  end

  def opened_abuse_complaint
    abuse_complaints.opened.first
  end
end
