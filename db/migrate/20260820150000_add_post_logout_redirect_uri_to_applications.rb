class AddPostLogoutRedirectUriToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :post_logout_redirect_uri, :text
  end
end
