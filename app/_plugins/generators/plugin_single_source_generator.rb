module PluginSingleSource
  class Generator < Jekyll::Generator
    priority :highest
    def generate(site)
      Dir.glob('app/_data/extensions/*/*/versions.yml').each do|f|
        data = SafeYAML.load(File.read(f))
        createPages(data, site, f)
      end
    end

    def createPages(data, site, configPath)
      max_version = data.map { |v| v['release'].gsub("-",".").gsub(/\.x/, ".0") }.sort_by { |v| Gem::Version.new(v) }.last
      data.each do |v,k|
        # Skip if a markdown file exists for this version
        name = configPath.gsub("app/_data/extensions/", "").gsub("/versions.yml","")
        next if File.exists?("app/_hub/#{name}/#{v['release']}.md")

        # Otherwise duplicate index.md
        plugin = name.split("/")
        source = "app/_hub/#{name}/_index.md"

        current_version = v['release'].gsub("-",".").gsub(/\.x/, ".0")

        # Add the index page rendering if we're on the latest release too
        puts "#{plugin.join('/')} :: \tCurrent: #{current_version} / Max: #{max_version}"
        if current_version == max_version
          site.pages << SingleSourcePage.new(site, v['release'], plugin[0], plugin[1], source, "index")
        else
          # Otherwise use the version as the filename
        site.pages << SingleSourcePage.new(site, v['release'], plugin[0], plugin[1], source, v['release'])
        end
      end
    end
  end

  class SingleSourcePage < Jekyll::Page
    def initialize(site, version, author, pluginName, sourcePath, permalinkName)
      # Configure variables that Jekyll depends on
      @site = site

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

      @data["version"] = version

      # The plugin hub uses version.html as the filename unless it's the most
      # recent version, in which case it uses index
      @data['permalink'] = @dir + "/" + permalinkName + ".html"

      # Set the layout if it's not already provided
      @data['layout'] = 'extension' unless self.data['layout']
    end
  end
end
