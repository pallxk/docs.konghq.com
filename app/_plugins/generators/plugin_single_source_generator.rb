module PluginSingleSource
  class Generator < Jekyll::Generator
    priority :highest
    def generate(site)
      Dir.glob('app/_data/extensions/kong-inc/vault-auth/versions.yml').each do|f|
        data = SafeYAML.load(File.read(f))
        createPages(data, site, f)
      end
    end

    def createPages(data, site, configPath)
      data.each do |v,k|
        # Skip if a markdown file exists for this version
        name = configPath.gsub("app/_data/extensions/", "").gsub("/versions.yml","")
        next if File.exists?("app/_hub/#{name}/#{v['release']}.md")

        # Otherwise duplicate index.md
        plugin = name.split("/")
        source = "app/_hub/#{name}/index.md"
        site.pages << SingleSourcePage.new(site, v['release'], plugin[0], plugin[1], source)
      end
    end
  end

  class SingleSourcePage < Jekyll::Page
    def initialize(site, version, author, pluginName, sourcePath)
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

      # The plugin hub uses version.html as the filename
      @data['permalink'] = @dir + "/" + version + ".html"

      # Set the layout if it's not already provided
      @data['layout'] = 'extension' unless self.data['layout']
    end
  end
end
