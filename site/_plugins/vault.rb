# Reads Vault/ and portfolio-details/ automatically and turns them into pages.
# Handles wikilinks, embeds, callouts, ==highlights==, math, attachments, nav tree,
# folder pages, the search index, and live-rebuilds when the Vault changes.
require "cgi"
require "yaml"
require "json"
require "date"

module Vault
  MEDIA = %w[png jpg jpeg gif webp svg avif bmp ico pdf mp4 webm mov mp3 ogg wav m4a].freeze
  IMAGES = %w[png jpg jpeg gif webp svg avif bmp ico].freeze
  KNOWN = %w[note abstract info todo tip success question warning failure danger bug example quote].freeze
  ALIAS = { "summary" => "abstract", "tldr" => "abstract", "hint" => "tip", "important" => "tip", "check" => "success",
            "done" => "success", "help" => "question", "faq" => "question", "caution" => "warning", "attention" => "warning",
            "fail" => "failure", "missing" => "failure", "error" => "danger", "cite" => "quote" }.freeze
  MATH_I = /(?<![\\$])\$(?![\s$])((?:\\.|[^$\\\n])+?)(?<![\s\\])\$(?![\d$])/

  class << self
    attr_accessor :listener
  end

  def self.slug(s)
    r = Jekyll::Utils.slugify(s.to_s)
    r.empty? ? "page" : r
  end

  def self.esc_url(s)
    s.gsub(" ", "%20")
  end

  def self.dirs(site)
    [site.config["vault_dir"] || "Vault", site.config["details_dir"] || "portfolio-details"].map { |d| File.expand_path(d, Dir.pwd) }
  end

  def self.parse(path)
    raw = File.read(path, encoding: "utf-8").sub(/\A\uFEFF/, "")
    if raw =~ /\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)(.*)\z/m
      fm, body = $1, $2
      data = begin
        YAML.safe_load(fm, permitted_classes: [Date, Time], aliases: true)
      rescue StandardError
        {}
      end
      [data.is_a?(Hash) ? data : {}, body]
    else
      [{}, raw]
    end
  end

  def self.plain(s)
    s.gsub(/!?\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]/) { $2 || $1 }
     .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1').gsub(/<[^>]+>/, " ")
     .gsub(/[#>*_=`~|$\\]/, " ").gsub(/\s+/, " ").strip
  end

  # ---------- Markdown transforms ----------
  def self.resolve(src, files, base)
    return src if src =~ %r{\A([a-z][a-z0-9+.-]*:|//)}i
    return base + src if src.start_with?("/")
    files[File.basename(CGI.unescape(src)).downcase] || src
  end

  def self.img(url, label)
    alt = []; cls = []; w = nil
    label.to_s.split("|").each do |t|
      t = t.strip
      if t =~ /\A(\d+)(?:x\d+)?\z/ then w = $1
      elsif %w[left right center].include?(t.downcase) then cls << "img-#{t.downcase}"
      else alt << t
      end
    end
    c = cls.empty? ? "" : %( class="#{cls.join(' ')}")
    %(<img src="#{CGI.escapeHTML(url)}" alt="#{CGI.escapeHTML(alt.join(' '))}"#{c}#{w ? %( width="#{w}") : ''}>)
  end

  def self.embed(inner, notes, files)
    target, *opts = inner.split("|")
    target = target.to_s.sub(/#.*\z/, "").strip
    url = files[File.basename(target).downcase]
    ext = File.extname(target).downcase.delete(".")
    if url && IMAGES.include?(ext) then img(url, opts.join("|"))
    elsif url then "[#{File.basename(target)}](#{url})"
    elsif (n = notes[target.downcase]) then "[#{target}](#{n})"
    else %(<span class="wikilink-missing">#{CGI.escapeHTML(target)}</span>)
    end
  end

  def self.text(seg, site)
    notes = site.config["vault_notes"]; files = site.config["vault_files"]; base = site.baseurl.to_s
    seg = seg.gsub(MATH_I) { %(<span class="math-i" data-tex="#{CGI.escapeHTML($1)}"></span>) }
    seg = seg.gsub(/!\[\[([^\]]+)\]\]/) { embed($1, notes, files) }
    seg = seg.gsub(/\[\[([^\]|#]+)(?:#([^\]|]*))?(?:\|([^\]]*))?\]\]/) do
      target = $1.strip; heading = $2; label = $3
      t = label && !label.empty? ? label : target
      url = notes[target.downcase] || notes[File.basename(target).downcase]
      if url
        url += "##{Jekyll::Utils.slugify(heading)}" if heading && !heading.empty?
        "[#{t}](#{url})"
      else
        %(<span class="wikilink-missing" title="Not published">#{CGI.escapeHTML(t)}</span>)
      end
    end
    # Obsidian comments are rendered as subtle editorial annotations without %% delimiters.
    seg = seg.gsub(/%%(.*?)%%/) do
      %(<span class="obsidian-comment" title="Author note">#{CGI.escapeHTML($1.strip)}</span>)
    end
    # Standard ==highlight== with an optional color suffix, e.g. ==text=={yellow}.
    seg = seg.gsub(/==(?!\s)(.+?)(?<!\s)==(?:\{(red|orange|yellow|green|cyan|blue|purple|grey|gray|#[0-9a-fA-F]{3,8})\})?/i) do
      content = $1
      color = $2
      klass = color && !color.start_with?("#") ? "hltr-#{color.downcase}" : (color ? "hltr-custom" : "")
      style = color && color.start_with?("#") ? %( style="--highlight-color: #{CGI.escapeHTML(color)}") : ""
      %(<mark#{klass.empty? ? "" : %( class="#{klass}")}#{style}>#{content}</mark>)
    end
    seg.gsub(/!\[([^\]]*)\]\(([^)\s]+)\)/) { img(resolve($2, files, base), $1) }
  end

  def self.inline(line, site)
    line.split(/(`+[^`\n]*`+)/).each_with_index.map { |s, i| i.odd? ? s : text(s, site) }.join
  end

  def self.transform(src, site)
    lines = src.lines; out = []; i = 0; fence = false
    while i < lines.length
      line = lines[i]
      if line =~ /\A\s*(```|~~~)/ then fence = !fence; out << line; i += 1; next end
      if fence then out << line; i += 1; next end
      if line =~ /\A\s*\$\$/
        buf = line.sub(/\A\s*\$\$/, "")
        if buf =~ /\$\$\s*\z/
          buf = buf.sub(/\$\$\s*\z/, "")
        else
          i += 1
          while i < lines.length
            l = lines[i]
            if l =~ /\$\$\s*\z/ then buf += l.sub(/\$\$\s*\z/, ""); break end
            buf += l; i += 1
          end
        end
        i += 1
        out << %(\n<div class="math-d" data-tex="#{CGI.escapeHTML(buf.strip)}"></div>\n\n)
        next
      end
      if line =~ /\A>[ \t]*\[!([\w-]+)\]([+-])?[ \t]*(.*?)[ \t]*\r?\n?\z/
        type = $1.downcase; fold = $2; title = $3.strip
        title = type.split("-").map(&:capitalize).join(" ") if title.empty?
        body = []; i += 1
        while i < lines.length && lines[i] =~ /\A>[ ]?(.*)\z/m
          body << $1; i += 1
        end
        canon = ALIAS[type] || type
        canon = "note" unless KNOWN.include?(canon)
        cls = "callout"
        cls += " is-collapsible" if fold
        cls += " is-collapsed" if fold == "-"
        arrow = fold ? %(<span class="callout-fold"></span>) : ""
        expanded = fold == "-" ? "false" : "true"
        out << %(\n<div class="#{cls}" data-callout="#{canon}" markdown="1">\n\n<div class="callout-title"#{fold ? %( role="button" tabindex="0" aria-expanded="#{expanded}") : ""}><span class="callout-icon" aria-hidden="true"></span><span class="callout-title-inner">#{CGI.escapeHTML(title)}</span>#{arrow}</div>\n\n<div class="callout-content" markdown="1">\n\n#{transform(body.join, site)}\n\n</div>\n\n</div>\n\n)
        next
      end
      if line =~ /\A\s*(?:[-*+]|\d+[.)])\s+\[[^\]]\][ \t]/
        line = line.sub(/\[([^\]])\]/) do
          c = $1
          cls = c == "-" ? "task-cb task-cancel" : "task-cb"
          %(<input type="checkbox" class="#{cls}"#{%w[x X -].include?(c) ? ' checked' : ''} onclick="return false">)
        end
      end
      out << inline(line, site); i += 1
    end
    out.join
  end

  Jekyll::Hooks.register :pages, :pre_render do |page|
    page.content = transform(page.content, page.site) if page.data["vault"]
  end

  class MediaFile < Jekyll::StaticFile
    def initialize(site, base, name, out_dir)
      super(site, base, "", name)
      @out_dir = out_dir
    end

    def destination(dest)
      Jekyll.sanitized_path(dest, File.join(@out_dir, @name))
    end

    def url
      "/" + File.join(@out_dir, @name)
    end

    def relative_path
      File.join(@out_dir, @name)
    end
  end

  class Builder < Jekyll::Generator
    safe true
    priority :highest

    def generate(site)
      @site = site; @base = site.baseurl.to_s
      vault, details = Vault.dirs(site)
      @notes = {}; @files = {}; @search = []; @pnav = []
      root = { name: "Notes", rel: [], folders: {}, files: [], url: "/notes/", index: false }
      walk(vault, root) if Dir.exist?(vault)
      emit_folders(root)
      read_details(details) if Dir.exist?(details)
      logo = site.config["logo"].to_s.downcase
      site.config["logo_url"] = @files[logo] || "#{@base}/assets/img/logo.svg"
      site.config["vault_notes"] = @notes
      site.config["vault_files"] = @files
      site.data["vault_nav"] = render(root)
      site.data["portfolio_nav"] = @pnav
      add_page("", "search.json", JSON.generate(@search), "permalink" => "/search.json", "render_with_liquid" => false)
    end

    private

    def add_page(dir, name, content, data)
      pg = Jekyll::PageWithoutAFile.new(@site, @site.source, dir, name)
      pg.content = content
      pg.data = data
      @site.pages << pg
      pg
    end

    def media(path, name, out)
      @site.static_files << MediaFile.new(@site, File.dirname(path), name, out)
      @files[name.downcase] ||= @base + Vault.esc_url("/#{out}/#{name}")
    end

    def media?(name)
      Vault::MEDIA.include?(File.extname(name).downcase.delete("."))
    end

    def register(keys, url)
      keys.compact.each { |k| @notes[k.to_s.downcase] ||= @base + url }
    end

    def walk(abs, node)
      Dir.children(abs).sort.each do |n|
        next if n.start_with?(".")
        path = File.join(abs, n)
        if File.directory?(path) && n =~ /\A_attachments?\z/i
          walk_media(path, (["notes"] + node[:rel] + [n.sub(/\A_+/, "")]).join("/"))
          next
        end
        next if n.start_with?("_")
        if File.directory?(path)
          rel = node[:rel] + [n]
          child = { name: n, rel: rel, folders: {}, files: [], index: false,
                    url: "/notes/" + rel.map { |s| Vault.slug(s) }.join("/") + "/" }
          node[:folders][n] = child
          walk(path, child)
        elsif File.extname(n).downcase == ".md"
          note(path, n, node)
        elsif media?(n)
          media(path, n, (["notes"] + node[:rel]).join("/"))
        end
      end
    end

    def walk_media(abs, out)
      Dir.children(abs).sort.each do |n|
        next if n.start_with?(".")
        p = File.join(abs, n)
        if File.directory?(p) then walk_media(p, "#{out}/#{n}")
        elsif media?(n) then media(p, n, out)
        end
      end
    end

    def note(path, name, node)
      data, body = Vault.parse(path)
      return if data["publish"] == false || data["published"] == false
      stem = File.basename(name, ".md")
      title = (data["title"] || stem).to_s
      index = stem.downcase == "index"
      url = index ? node[:url] : node[:url] + Vault.slug(stem) + "/"
      node[:index] = true if index
      data = data.merge("title" => title, "layout" => "note", "permalink" => url, "vault" => true, "render_with_liquid" => false)
      add_page(File.dirname(url.chomp("/")).sub(%r{\A/}, ""), "#{Vault.slug(stem)}.md", body, data)
      node[:files] << { title: title, url: url, order: data["order"] } unless index
      register([stem, title, (node[:rel] + [stem]).join("/")] + Array(data["aliases"] || data["alias"]), url)
      @search << { t: title, u: @base + url, d: data["description"].to_s, p: node[:rel].join(" / "), k: "note", c: Vault.plain(body), a: (Array(data["aliases"] || data["alias"]) + Array(data["tags"])).join(" ") }
    end

    def listing(node)
      l = node[:folders].keys.sort_by(&:downcase).map { |k| "- **[#{k}](#{@base}#{node[:folders][k][:url]})**" }
      l += sorted(node[:files]).map { |f| "- [#{f[:title]}](#{@base}#{f[:url]})" }
      l.empty? ? "*Nothing here yet.*" : l.join("\n")
    end

    def emit_folders(node)
      unless node[:index]
        title = node[:rel].empty? ? "Notes" : node[:name]
        add_page(File.dirname(node[:url].chomp("/")).sub(%r{\A/}, ""), "#{node[:rel].empty? ? 'notes' : Vault.slug(node[:name])}.md", listing(node),
                 "title" => title, "layout" => "note", "permalink" => node[:url], "render_with_liquid" => false)
        register([node[:rel].join("/")], node[:url]) unless node[:rel].empty?
        @notes[node[:name].downcase] ||= @base + node[:url] unless node[:rel].empty?
      end
      unless node[:rel].empty?
        @search << { t: node[:name], u: @base + node[:url], d: "", p: node[:rel][0..-2].join(" / "), k: "folder", c: "" }
      end
      node[:folders].each_value { |c| emit_folders(c) }
    end

    def read_details(abs)
      Dir.children(abs).sort.each do |n|
        next if n.start_with?(".", "_")
        path = File.join(abs, n)
        next if File.directory?(path)
        if File.extname(n).downcase == ".md"
          data, body = Vault.parse(path)
          next if data["publish"] == false || data["published"] == false
          stem = File.basename(n, ".md"); key = stem.downcase
          url = key == "home" ? "/" : (key == "about" ? "/about/" : "/#{Vault.slug(stem)}/")
          title = (data["title"] || (key == "home" ? "Home" : stem)).to_s
          data = data.merge("title" => title, "layout" => "page", "permalink" => url, "vault" => true, "render_with_liquid" => false)
          data["hide_title"] = true if key == "home" && !data.key?("hide_title")
          add_page("", key == "home" ? "index.md" : "#{Vault.slug(stem)}.md", body, data)
          register([stem, title], url)
          @pnav << { "title" => title, "url" => @base + url } unless %w[home about].include?(key) || data["nav"] == false
          @search << { t: title, u: @base + url, d: data["description"].to_s, p: "", k: "page", c: Vault.plain(body), a: (Array(data["aliases"] || data["alias"]) + Array(data["tags"])).join(" ") }
        elsif media?(n)
          media(path, n, "portfolio")
        end
      end
    end

    def sorted(files)
      files.sort_by { |f| [(Float(f[:order]) rescue 1e9), f[:title].downcase] }
    end

    def h(s)
      CGI.escapeHTML(s.to_s)
    end

    def render(node)
      html = +"<ul>"
      node[:folders].sort_by { |k, _| k.downcase }.each do |_, f|
        html << %(<li><details><summary><a href="#{h(@base + f[:url])}">#{h f[:name]}</a></summary>#{render(f)}</details></li>)
      end
      sorted(node[:files]).each { |f| html << %(<li><a href="#{h(@base + f[:url])}">#{h f[:title]}</a></li>) }
      html << "</ul>"
    end
  end

  # Rebuild when the Vault / portfolio-details change (jekyll serve only watches site/).
  Jekyll::Hooks.register :site, :post_write do |site|
    next unless site.config["watch"] && Vault.listener.nil?
    begin
      require "listen"
      dirs = Vault.dirs(site).select { |d| Dir.exist?(d) }
      lock = Mutex.new
      Vault.listener = Listen.to(*dirs, ignore: [%r{/\.(obsidian|trash|git)(/|\z)}], latency: 0.6) do |*|
        lock.synchronize do
          begin
            Jekyll.logger.info "Vault:", "change detected, rebuilding..."
            site.process
          rescue StandardError => e
            Jekyll.logger.warn "Vault:", e.message
          end
        end
      end
      Vault.listener.start
    rescue LoadError, StandardError => e
      Vault.listener = false
      Jekyll.logger.warn "Vault:", "live rebuild unavailable (#{e.message}); restart jekyll to see Vault changes"
    end
  end
end
