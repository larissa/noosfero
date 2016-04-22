require 'ostruct'

module ExternalUser
  extend ActiveSupport::Concern

  included do
    attr_accessor :external_person_id
  end

  def external_person
    ExternalPerson.where(id: self.external_person_id).first
  end

  module ClassMethods
    def webfinger_lookup(login, domain, environment)
      if login && domain && environment.has_federated_network?(domain)
        # Ask if network at <domain> has user with login <login>
        # FIXME: Make an actual request to the federated network, which should return nil if not found
        {
          login: login
        }
      else
        nil
      end
    end

    def external_login(login, password, domain)
      # Call Noosfero /api/login
      uri = URI.parse('http://' + domain + '/api/v1/login')
      response = Net::HTTP.post_form(uri, { login: login, password: password })
      if response.code == '301'
        # Follow a redirection
        uri = URI.parse(response.header['location'])
        response = Net::HTTP.post_form(uri, { login: login, password: password })
      end
      response.code.to_i / 100 === 2 ? JSON.parse(response.body) : nil
    end

    # Authenticates a user from an external social network
    def external_authenticate(username, password, environment)
      login, domain = username.split('@')
      webfinger = User.webfinger_lookup(login, domain, environment)
      if webfinger
        user = User.external_login(login, password, domain)
        if user
          u = User.new
          u.login = login
          # FIXME: Instead of the struct below, we should use the "webfinger" object returned by the webfinger_lookup method
          webfinger = OpenStruct.new(
                        identifier: user['user']['person']['identifier'],
                        name: user['user']['person']['name'],
                        domain: domain,
                        email_md5: Digest::MD5.hexdigest(user['user']['email'])
                      )
          u.external_person_id = ExternalPerson.get_or_create(webfinger).id
          return u
        end
      end
      nil
    end
  end
end
