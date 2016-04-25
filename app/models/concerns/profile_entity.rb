module ProfileEntity
  extend ActiveSupport::Concern

  included do
    attr_accessible :name, :identifier, :environment

    validates_presence_of :identifier, :name

    belongs_to :environment
    has_many :search_terms, :as => :context
    has_many :abuse_complaints, :as => :reported, :foreign_key => 'requestor_id', :dependent => :destroy

    before_create :set_default_environment

  end

  def disable
    self.visible = false
    self.save
  end

  def enable
    self.visible = true
    self.save
  end

  def opened_abuse_complaint
    abuse_complaints.opened.first
  end

  def set_default_environment
    if self.environment.nil?
      self.environment = Environment.default
    end
    true
  end

  # returns +false+
  def person?
    self.kind_of?(Person)
  end

  def enterprise?
    self.kind_of?(Enterprise)
  end

  def organization?
    self.kind_of?(Organization)
  end

  def community?
    self.kind_of?(Community)
  end

  include ActionView::Helpers::TextHelper
  def short_name(chars = 40)
    if self[:nickname].blank?
      if chars
        truncate self.name, length: chars, omission: '...'
      else
        self.name
      end
    else
      self[:nickname]
    end
  end

end
