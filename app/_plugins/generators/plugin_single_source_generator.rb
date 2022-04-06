module PluginSingleSource
  class Generator < Jekyll::Generator
    priority :highest
    def generate(site)
      site.data['ssg_hub'] = []
      seen = []

      Dir.glob('app/_data/extensions/*/*/versions.yml').each do|f|
        name = f.gsub("app/_data/extensions/", "").gsub("/versions.yml","")
        seen << name
        data = SafeYAML.load(File.read(f))
        createPages(data, site, name)
      end

      # Add any files that did not have a corresponding versions.yml
      Dir.glob('app/_hub/*/*/_index.md').each do|f|
        name = f.gsub("app/_hub/", "").gsub("/_index.md","")
        next if seen.include?(name)
        createPages([{'release' => "1.0.0"}], site, name) # If there's no version, assume it's 1.0.0
      end

      puts site.data['ssg_hub'].map{ |v| v.data['name'] }.to_json.green

    end

    def createPages(versions, site, name)
      max_version = versions.map { |v| v['release'].gsub("-",".").gsub(/\.x/, ".0") }.sort_by { |v| Gem::Version.new(v) }.last
      set_version = versions.size > 1
      versions.each do |v,k|
        current_version = v['release'].gsub("-",".").gsub(/\.x/, ".0")

        # Skip if a markdown file exists for this version
        # and we're not generating the index version
        next if File.exists?("app/_hub/#{name}/#{v['release']}.md") && current_version != max_version

        # Otherwise duplicate index.md
        plugin = name.split("/")
        source = "app/_hub/#{name}/_index.md"


        # Add the index page rendering if we're on the latest release too
        permalink = v['release']
        permalink = "index" if current_version == max_version

        page = SingleSourcePage.new(site, v['release'], plugin[0], plugin[1], source, permalink, set_version)
        site.pages << page

        # Make sure we add the page to site.hub for later iteration
        site.data['ssg_hub'] << page
      end
    end
  end

  class SingleSourcePage < Jekyll::Page
    def initialize(site, version, author, pluginName, sourcePath, permalinkName, setVersion)
      # Configure variables that Jekyll depends on
      @site = site

      # Make sure the source path is still index.md to generate the extension listing
      @path = sourcePath.gsub("_index", permalinkName)

      # Set self.ext and self.basename by extracting information from the page filename
      process(version + ".md")

      # This is the directory that we're going to write the output file to
      @dir = "hub/#{author}/#{pluginName}"

      content = File.read(sourcePath)

      # Load content + frontmatter from the file
      if content =~ Jekyll::Document::YAML_FRONT_MATTER_REGEXP
        @content = Regexp.last_match.post_match
        @data = SafeYAML.load(Regexp.last_match(1))
      end

      @data["version"] = version if setVersion
      @data["is_latest"] = permalinkName == "index"

      # The plugin hub uses version.html as the filename unless it's the most
      # recent version, in which case it uses index
      @data['permalink'] = @dir + "/" + permalinkName + ".html"

      # Set the layout if it's not already provided
      @data['layout'] = 'extension' unless self.data['layout']
    end
  end
end
