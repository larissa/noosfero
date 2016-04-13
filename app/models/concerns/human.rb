module Human
  extend ActiveSupport::Concern

  included do
    has_many :comments, :foreign_key => :author_id
    has_many :abuse_reports, :foreign_key => 'reporter_id', :dependent => :destroy

    scope :abusers, -> {
      joins(:abuse_complaints).where('tasks.status = 3').distinct.select('profiles.*')
    }
    scope :non_abusers, -> {
      distinct.select("profiles.*").
      joins("LEFT JOIN tasks ON profiles.id = tasks.requestor_id AND tasks.type='AbuseComplaint'").
      where("tasks.status != 3 OR tasks.id is NULL")
    }
  end

  def already_reported?(profile)
    abuse_reports.any? { |report| report.abuse_complaint.reported == profile && report.abuse_complaint.opened? }
  end

  def register_report(abuse_report, profile)
    AbuseComplaint.create!(:reported => profile, :target => profile.environment) if !profile.opened_abuse_complaint
    abuse_report.abuse_complaint = profile.opened_abuse_complaint
    abuse_report.reporter = self
    abuse_report.save!
  end

  def abuser?
    AbuseComplaint.finished.where(:requestor_id => self).count > 0
  end

end
