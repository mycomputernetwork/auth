require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# omniauth-rails_csrf_protection still uses ActiveSupport::Configurable, which
# Rails 8.2 removes. Silencing only gem loading keeps our own deprecations loud.
ActiveSupport.deprecator.silence { Bundler.require(*Rails.groups) }

module McnAuth
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.generators.system_tests = nil
  end
end
