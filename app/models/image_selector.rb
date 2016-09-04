# ImageSelector is a policy object that picks up the right Docker
# image given the running language and the version of it.
class ImageSelector
  def initialize(lang, version)
    @lang = lang
    @version = version
  end

  def name
    selected_version = version
    available_versions = LANGUAGE_VERSIONS[lang]

    if selected_version.blank?
      selected_version = if available_versions.empty?
                           available_versions.first
                         else
                           'latest'
                         end
    end

    "#{DOCKER_IMAGES[lang]}:#{selected_version}"
  end

  private

  attr_reader :lang, :version
end
