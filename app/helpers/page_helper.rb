module PageHelper
  def langauage_selector
    select_tag "lang", options_for_select(language_selections)
  end

  def language_selections
    [].tap do |selections|
      LANGUAGE_VERSIONS.each do |lang, versions|
        versions.each do |version|
          wording = if version == "latest"
            lang.to_s.capitalize
          else
            "#{lang.to_s.capitalize} - #{version}"
          end
          selections << [wording, "#{lang} #{version}"]
        end
      end
    end
  end
end
