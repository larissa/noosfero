#inspired by https://github.com/code4lib/ruby-oai/blob/master/lib/oai/harvester/harvest.rb
class VirtuosoPlugin::DspaceHarvest

  DC_CONVERSION = [:title, :creator, :subject, :description, :date, :type, :identifier, :language, :rights, :format]

  def initialize(environment)
    @environment = environment
  end

  def settings
    @settings ||= Noosfero::Plugin::Settings.new(@environment, VirtuosoPlugin)
  end

  def dspace_client
    @dspace_client ||= OAI::Client.new("#{settings.dspace_uri}/oai/request")
  end

  def virtuoso_client
    @virtuoso_client ||= RDF::Virtuoso::Repository.new("#{settings.virtuoso_uri}/sparql", :update_uri => "#{settings.virtuoso_uri}/sparql-auth", :username => settings.virtuoso_username, :password => settings.virtuoso_password, :auth_method => 'digest', :timeout => 30)
  end

  def triplify(record)
    metadata = VirtuosoPlugin::DublinCoreMetadata.new(record.metadata)
    puts "triplify #{record.header.identifier}"

    DC_CONVERSION.each do |c|
      values = [metadata.send(c)].flatten.compact
      values.each do |value|
        query = RDF::Virtuoso::Query.insert_data([RDF::URI.new(metadata.identifier), RDF::URI.new("http://purl.org/dc/elements/1.1/#{c}"), value]).graph(RDF::URI.new(settings.dspace_uri))
        virtuoso_client.insert(query)
      end
    end
  end

  def run
    harvest_time = Time.now.utc
    params = settings.last_harvest ? {:from => settings.last_harvest.utc} : {}
    puts "starting harvest #{params} #{settings.dspace_uri} #{settings.virtuoso_uri}"
    begin
      records = dspace_client.list_records(params)
      records.each do |record|
        triplify(record)
      end
    rescue OAI::Exception => ex
      puts ex.to_s
      if ex.code != 'noRecordsMatch'
        puts "unexpected error"
        raise ex
      end
    end
    settings.last_harvest = harvest_time
    settings.save!
    puts "ending harvest #{harvest_time}"
  end

  def start(from_start = false)
    if find_job.empty?
      if from_start
        settings.last_harvest = nil
        settings.save!
      end

      job = VirtuosoPlugin::DspaceHarvest::Job.new(@environment.id)
      Delayed::Job.enqueue(job)
    end
  end

  def find_job
    Delayed::Job.where(:handler => "--- !ruby/struct:VirtuosoPlugin::DspaceHarvest::Job\nenvironment_id: #{@environment.id}\n")
  end

  class Job < Struct.new(:environment_id)
    def perform
      environment = Environment.find(environment_id)
      harvest = VirtuosoPlugin::DspaceHarvest.new(environment)
      harvest.run
    end
  end

end
