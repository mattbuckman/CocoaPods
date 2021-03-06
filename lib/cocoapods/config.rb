module Pod

  # Stores the global configuration of CocoaPods.
  #
  class Config

    # The default settings for the configuration.
    #
    # Users can specify custom settings in `~/.cocoapods/config.yaml`.
    # An example of the contents of this file might look like:
    #
    #     ---
    #     skip_repo_update: true
    #     new_version_message: false
    #
    DEFAULTS = {
      :verbose             => false,
      :silent              => false,
      :skip_repo_update    => false,
      :aggressive_cache    => false,

      :clean               => true,
      :integrate_targets   => true,
      :new_version_message => true,
    }

    public

    #-------------------------------------------------------------------------#

    # @!group UI

    # @return [Bool] Whether CocoaPods should provide detailed output about the
    #         performed actions.
    #
    attr_accessor :verbose
    alias_method  :verbose?, :verbose

    # @return [Bool] Whether CocoaPods should produce not output.
    #
    attr_accessor :silent
    alias_method  :silent?, :silent

    # @return [Bool] Whether a message should be printed when a new version of
    #         CocoaPods is available.
    #
    attr_accessor :new_version_message
    alias_method  :new_version_message?, :new_version_message

    #-------------------------------------------------------------------------#

    # @!group Installation

    # @return [Bool] Whether the installer should clean after the installation.
    #
    attr_accessor :clean
    alias_method  :clean?, :clean

    # @return [Bool] Whether CocoaPods should integrate a user target and build
    #         the workspace or just create the Pods project.
    #
    attr_accessor :integrate_targets
    alias_method  :integrate_targets?, :integrate_targets


    # @return [Bool] Whether the installer should skip the repos update.
    #
    attr_accessor :skip_repo_update
    alias_method  :skip_repo_update?, :skip_repo_update

    # Allows to set whether the downloader should use more aggressive caching
    # options.
    #
    # @note The aggressive cache has lead to issues if a tag is updated to
    #       point to another commit.
    #
    attr_writer :aggressive_cache

    # @return [Bool] Whether the downloader should use more aggressive caching
    #         options.
    #
    def aggressive_cache?
      @aggressive_cache || (ENV['CP_AGGRESSIVE_CACHE'] != 'FALSE')
    end

    public

    #-------------------------------------------------------------------------#

    # @!group Initialization

    def initialize
      configure_with(DEFAULTS)

      if user_settings_file.exist?
        require 'yaml'
        user_settings = YAML.load_file(user_settings_file)
        configure_with(user_settings)
      end
    end

    def verbose
      @verbose && !silent
    end

    public

    #-------------------------------------------------------------------------#

    # @!group Paths

    # @return [Pathname] the directory where the CocoaPods sources are stored.
    #
    def repos_dir
      @repos_dir ||= Pathname.new(ENV['CP_REPOS_DIR'] || "~/.cocoapods").expand_path
    end

    attr_writer :repos_dir

    # @return [Pathname] the root of the CocoaPods installation where the
    #         Podfile is located.
    #
    def installation_root
      current_path = Pathname.pwd
      unless @installation_root
        while(!current_path.root?)
          if podfile_path_in_dir(current_path)
            @installation_root = current_path
            unless current_path == Pathname.pwd
              UI.puts("[in #{current_path}]")
            end
            break
          else
            current_path = current_path.parent
          end
        end
        @installation_root ||= Pathname.pwd
      end
      @installation_root
    end

    attr_writer :installation_root
    alias :project_root :installation_root

    # @return [Pathname] The root of the sandbox.
    #
    def sandbox_root
      @sandbox_root ||= installation_root + 'Pods'
    end

    attr_writer :sandbox_root
    alias :project_pods_root :sandbox_root

    # @return [Sandbox] The sandbox of the current project.
    #
    def sandbox
      @sandbox ||= Sandbox.new(sandbox_root)
    end

    # @return [Podfile] The Podfile to use for the current execution.
    # @return [Nil] If no Podfile is available.
    #
    def podfile
      @podfile ||= Podfile.from_file(podfile_path) if podfile_path
    end
    attr_writer :podfile

    # @return [Lockfile] The Lockfile to use for the current execution.
    # @return [Nil] If no Lockfile is available.
    #
    def lockfile
      @lockfile ||= Lockfile.from_file(lockfile_path) if lockfile_path
    end

    # Returns the path of the Podfile.
    #
    # @note The Podfile can be named either `CocoaPods.podfile.yaml`,
    #       `CocoaPods.podfile` or `Podfile`.  The first two are preferred as
    #       they allow to specify an OS X UTI.
    #
    # @return [Pathname]
    # @return [Nil]
    #
    def podfile_path
      @podfile_path ||= podfile_path_in_dir(installation_root)
    end

    # Returns the path of the Lockfile.
    #
    # @note The Lockfile is named `Podfile.lock`.
    #
    def lockfile_path
      @lockfile_path ||= installation_root + 'Podfile.lock'
    end

    private

    #-------------------------------------------------------------------------#

    # @!group Private helpers

    # @return [Pathname] The path of the file which contains the user settings.
    #
    def user_settings_file
      repos_dir + "config.yaml"
    end

    # Sets the values of the attributes with the given hash.
    #
    # @param  [Hash{String,Symbol => Object}] values_by_key
    #         The values of the attributes grouped by key.
    #
    # @return [void]
    #
    def configure_with(values_by_key)
      return unless values_by_key
      values_by_key.each do |key, value|
        self.instance_variable_set("@#{key}", value)
      end
    end

    # @return [Array<String>] The filenames that the Podfile can have ordered
    #         by priority.
    #
    PODFILE_NAMES = [
      'CocoaPods.podfile.yaml',
      'CocoaPods.podfile',
      'Podfile',
    ]

    # Returns the path of the Podfile in the given dir if any exists.
    #
    # @param  [Pathname] dir
    #         The directory where to look for the Podfile.
    #
    # @return [Pathname] The path of the Podfile.
    # @return [Nil] If not Podfile was found in the given dir
    #
    def podfile_path_in_dir(dir)
      PODFILE_NAMES.each do |filename|
        candidate = dir + filename
        if candidate.exist?
          return candidate
        end
      end
      nil
    end

    public

    #-------------------------------------------------------------------------#

    # @!group Singleton

    # @return [Config] the current config instance creating one if needed.
    #
    def self.instance
      @instance ||= new
    end

    # Sets the current config instance. If set to nil the config will be
    # recreated when needed.
    #
    # @param  [Config, Nil] the instance.
    #
    # @return [void]
    #
    def self.instance=(instance)
      @instance = instance
    end

    # Provides support for accessing the configuration instance in other
    # scopes.
    #
    module Mixin
      def config
        Config.instance
      end
    end
  end
end
