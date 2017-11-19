require 'pathname'
require 'dotenv'

# dashboard app specific configuration
class Configuration
  attr_writer :app_development_enabled
  attr_writer :app_sharing_enabled

  # FIXME: temporary
  attr_accessor :app_sharing_facls_enabled
  alias_method :app_sharing_facls_enabled?, :app_sharing_facls_enabled

  # The app's configuration root directory
  # @return [Pathname] path to configuration root
  def config_root
    Pathname.new(ENV["OOD_APP_CONFIG_ROOT"] || "/etc/ood/config/apps/dashboard")
  end

  def initializers_root
    Pathname.new(ENV["OOD_APP_INITIALIZERS_ROOT"] || config_root.join("initializers"))
  end

  def load_external_config?
    ENV['OOD_LOAD_EXTERNAL_CONFIG'] || (rails_env == "production")
  end

  # Load the dotenv local files first, then the /etc dotenv files and
  # the .env and .env.production or .env.development files.
  #
  # Doing this in two separate loads means OOD_APP_CONFIG_ROOT can be specified in
  # the .env.local file, which will specify where to look for the /etc dotenv
  # files. The default for OOD_APP_CONFIG_ROOT is /etc/ood/config/apps/myjobs and
  # both .env and .env.production will be searched for there.
  def load_dotenv_files
    # .env.local first, so it can override OOD_APP_CONFIG_ROOT
    Dotenv.load(*dotenv_local_files) unless dotenv_local_files.empty?

    # load the rest of the dotenv files
    Dotenv.load(*dotenv_files)
  end

  def app_development_enabled?
    return @app_development_enabled if defined? @app_development_enabled
    ENV['OOD_APP_DEVELOPMENT'].present? || DevRouter.base_path.exist?
  end
  alias_method :app_development_enabled, :app_development_enabled?

  def app_sharing_enabled?
    return @app_sharing_enabled if defined? @app_sharing_enabled
    @app_sharing_enabled = ENV['OOD_APP_SHARING'].present?
  end
  alias_method :app_sharing_enabled, :app_sharing_enabled?

  def brand_bg_color
    ENV.values_at('OOD_BRAND_BG_COLOR', 'BOOTSTRAP_NAVBAR_DEFAULT_BG', 'BOOTSTRAP_NAVBAR_INVERSE_BG').compact.first
  end

  def brand_link_active_bg_color
    ENV.values_at('OOD_BRAND_LINK_ACTIVE_BG_COLOR', 'BOOTSTRAP_NAVBAR_DEFAULT_LINK_ACTIVE_BG','BOOTSTRAP_NAVBAR_INVERSE_LINK_ACTIVE_BG' ).compact.first
  end

  def dataroot
    OodAppkit.dataroot || default_dataroot
  end

  def default_dataroot
    # copied from OodAppkit::Configuration#set_default_configuration
    # FIXME: note that this would be invalid if the dataroot where
    # overridden in an initializer by modifying OodAppkit.dataroot which is why
    # this ability should probably be deprecated

    root = ENV['OOD_DATAROOT'] || ENV['RAILS_DATAROOT']
    root ||= "~/#{ENV['OOD_PORTAL'] || "ondemand"}/data/#{ENV['APP_TOKEN']}" if ENV['APP_TOKEN']
    root
  end

  private

  # The environment
  # @return [String] "development", "test", or "production"
  def rails_env
    ENV['RAILS_ENV'] || "development"
  end

  # The app's root directory
  # @return [Pathname] path to configuration root
  def app_root
    Pathname.new(File.expand_path("../../",  __FILE__))
  end

  def dotenv_local_files
    [
      app_root.join(".env.#{rails_env}.local"),
      (app_root.join(".env.local") unless rails_env == "test"),
    ].compact
  end

  def dotenv_files
    [
      (config_root.join("env") if load_external_config?),
      app_root.join(".env.#{rails_env}"),
      app_root.join(".env")
    ].compact
  end

end

# global instance to access and use
AppConfig = Configuration.new
