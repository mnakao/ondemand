#
# Manages profile based configuration properties.
# Property values are configured in configuration files under ::Configuration.config_directory and read from ::Configuration.config object.
#
# For backwards compatibility, properties can be configured to read values from the environment object: ENV.
# Environment values will have precedence over values defined in configuration files.
#
# Property lookup is hierarchical based on a profile value defined in CurrentUser.user_settings[:profile].
# First the lookup is done in the profile configuration if any, if no value is defined, the root configuration is used.
#
# Example configuration with a team1 profile:
#   dashboard_logo: "/public/ood.png"
#   profiles:
#     team1:
#       dashboard_logo: "/public/team1.png"
#
class UserConfiguration

  USER_PROPERTIES = [
    ConfigurationProperty.property(name: :dashboard_header_img_logo, read_from_env: true),
    # Whether we display the Dashboard logo image
    ConfigurationProperty.with_boolean_mapper(name: :disable_dashboard_logo, default_value: false, read_from_env: true, env_names: ['OOD_DISABLE_DASHBOARD_LOGO', 'DISABLE_DASHBOARD_LOGO']),
    # URL to the Dashboard logo image
    ConfigurationProperty.property(name: :dashboard_logo, read_from_env: true),
    # Dashboard logo height used to set the height style attribute
    ConfigurationProperty.property(name: :dashboard_logo_height, read_from_env: true),
    ConfigurationProperty.property(name: :brand_bg_color, read_from_env: true, env_names: ['OOD_BRAND_BG_COLOR', 'BOOTSTRAP_NAVBAR_DEFAULT_BG', 'BOOTSTRAP_NAVBAR_INVERSE_BG']),
    ConfigurationProperty.property(name: :brand_link_active_bg_color, read_from_env: true, env_names: ['OOD_BRAND_LINK_ACTIVE_BG_COLOR', 'BOOTSTRAP_NAVBAR_DEFAULT_LINK_ACTIVE_BG', 'BOOTSTRAP_NAVBAR_INVERSE_LINK_ACTIVE_BG']),

    # The dashboard's landing page layout. Defaults to nil.
    ConfigurationProperty.property(name: :dashboard_layout),
    # The configured pinned apps
    ConfigurationProperty.property(name: :pinned_apps, default_value: []),
    # The length of the "Pinned Apps" navbar menu
    ConfigurationProperty.property(name: :pinned_apps_menu_length, default_value: 6),

    # Links to change profile under the Help navigation menu
    # example:
    # profile_links:
    #   - id: default
    #     name: "Default"
    #     icon: "cog"
    #   - id: profile1
    #     name: "Team2"
    #     icon: "user"
    #
    ConfigurationProperty.property(name: :profile_links, default_value: []),

    # Custom CSS files to add to the application.html.erb template
    # The files need to be deployed to the Apache public directory: /var/www/ood/public
    # The URL path will be prepended with the public_url property
    # example:
    # custom_css_files: ["core.css", "/custom/team1.css"]
    ConfigurationProperty.property(name: :custom_css_files, default_value: []),

    ConfigurationProperty.property(name: :dashboard_title, default_value: 'Open OnDemand', read_from_env: true),
  ].freeze

  def initialize
    @config = ::Configuration.config
    add_property_methods
  end

  # Sets the Bootstrap 4 navbar type
  # See more about Bootstrap color schemes: https://getbootstrap.com/docs/4.6/components/navbar/#color-schemes
  # Supported values: ['dark', 'inverse', 'light', 'default']
  # @return [String, 'dark'] Default to dark
  def navbar_type
    type = ENV['OOD_NAVBAR_TYPE'] || fetch(:navbar_type)
    if type == 'inverse' || type == 'dark'
      'dark'
    elsif type == 'default' || type == 'light'
      'light'
    else
      'dark'
    end
  end

  # What to group pinned apps by
  # @return [String, ""] Defaults to ""
  def pinned_apps_group_by
    group_by = ENV['OOD_PINNED_APPS_GROUP_BY'] || fetch(:pinned_apps_group_by, '')

    # FIXME: the user_configuration shouldn't really know the API of
    # OodApp or subclasses. This is a hack because subclasses of OodApp overload
    # the category and subcategory to something new while saving the original.
    # The fix would be to move this knowledge to somewhere more appropriate than here.
    if group_by == 'category' || group_by == 'subcategory'
      "original_#{group_by}"
    else
      group_by
    end
  end

  def public_url
    path = ENV['OOD_PUBLIC_URL'] || fetch(:public_url, '/public')
    # do not load any resources using public_url from another host. Only allow relative paths.
    path.start_with?('/') ? Pathname.new(path) : Pathname.new('/public')
  end

  # The current user profile. Used to select the configuration properties.
  def profile
    CurrentUser.user_settings[:profile].to_sym if CurrentUser.user_settings[:profile]
  end

  private

  # Performs the property lookup in the configuration object.
  # First, it looks into the profile configuration as defined by current user profile.
  # If no value is defined, it looks into the root configuration.
  def fetch(key_value, default_value = nil)
    key = key_value ? key_value.to_sym : nil
    profile_config = @config.dig(:profiles, profile) || {}

    # Returns the value if they key is present in the profile, even if the value is nil
    # This is to mimic the Hash.fetch behaviour that only uses the default_value when key is not present
    profile_config.key?(key) ? profile_config[key] : @config.fetch(key, default_value)
  end

  # Dynamically adds methods to this class based on the USER_PROPERTIES defined.
  # The name of the method is the name of the property.
  # The value is based on ENV and config objects, depending on the configuration of the property.
  def add_property_methods
    UserConfiguration::USER_PROPERTIES.each do |property|
      define_singleton_method(property.name) do
        environment_value = property.map_string(property.environment_names.map{|key| ENV[key]}.compact.first) if property.read_from_environment?
        environment_value.nil? ? fetch(property.name, property.default_value) : environment_value
      end
    end
  end
end