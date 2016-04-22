module ExternalUser
  included do
    attr_accessor :external_person_id
  end

  def self.webfinger_lookup(login, domain, environment)
    if login && domain && environment.has_federated_network?(domain)
      # Ask if network at <domain> has user with login <login>
      # FIXME: Make an actual request to the federated network, which should return nil if not found
      {
        login: login
      }
    end
    nil
  end

  def self.external_login
    # Call Noosfero /api/login
  end

  # Authenticates a user from an external social network
  def self.external_authenticate(username, password, environment)
    login, domain = username.split('@')
    webfinger = User.webfinger_lookup(login, domain, environment)
    if webfinger
      user = User.external_login(login, password, domain)
      if user
        u = User.new
        # Set other fields on "u" based on information in "user" returned by API
        u.external_person_id = ExternalPerson.get_or_create(login, domain).id
        return u
      end
    end
    nil
  end
end
