Doorkeeper::OpenidConnect.configure do
  issuer { |_resource_owner, _application, _request| Issuer.url }

  signing_key Rails.application.credentials.oidc_signing_key

  subject_types_supported [:public]

  subject { |resource_owner, _application| resource_owner.id }

  resource_owner_from_access_token { |access_token| User.active.find_by(id: access_token.resource_owner_id) }

  auth_time_from_resource_owner { |resource_owner| resource_owner.created_at }

  reauthenticate_resource_owner do |_resource_owner, return_to|
    sign_out
    store_return_to(return_to)
    redirect_to sign_in_url
  end

  select_account_for_resource_owner do |_resource_owner, return_to|
    store_return_to(return_to)
    redirect_to sign_in_url
  end

  claims do
    claim :sid, scope: :openid, response: [:id_token] do |_resource_owner, _scopes, access_token|
      access_token.sid
    end

    claim :email, scope: :email, response: %i[user_info id_token] do |resource_owner|
      resource_owner.email
    end

    claim :email_verified, scope: :email, response: %i[user_info id_token] do
      true
    end

    claim :name, scope: :profile, response: %i[user_info id_token] do |resource_owner|
      resource_owner.name
    end
  end
end
