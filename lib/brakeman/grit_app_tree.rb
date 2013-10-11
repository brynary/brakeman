require "brakeman/app_tree"
require "brakeman/grit_repo"
require "active_support/core_ext"
require "pathname"
require "grit"
require "uri"
require "rack/utils"

module Brakeman
  class GritAppTree < AppTree  
    attr_accessor :grit_repo

    def initialize(url, skip_files = nil)
      @uri = URI.parse(url)
      @use_smoke = @uri.scheme == "bertrpc"

      parse_uri_params

      @skip_files = skip_files
      @grit_repo = GritRepo.new(@uri, @repo_id).repo
    end

    def valid?
      exists?("config/environment.rb")
    end

    def expand_path(path)
      raise "TODO expand_path"
    end

    def read(path)
      @grit_repo.blob(file_index[apply_prefix(path)]).data
    end

    def read_path(path)
      read(path)
    end

    def path_exists?(path)
      raise "TODO path_exists?"
    end

    def exists?(path)
      file_index[apply_prefix(path)]
    end

    def template_paths
      @template_paths ||= VIEW_EXTENSIONS.map do |extension|
        find_paths("app/views", "*.#{extension}")
      end.flatten.uniq
    end

    def layout_exists?(name)
      !glob("app/views/layouts/#{name}.html.erb").empty? ||
      !glob("app/views/layouts/#{name}.html.haml").empty?
    end

  private
    def parse_uri_params
      if @use_smoke == true
        uri_parts = @uri.path.sub(/^\//, "").split("/")
        @prefix = uri_parts[3..-1].to_a.join("/")
        @repo_id = uri_parts[1]
        @commit_sha = uri_parts[2]
      else
        parsed_query = Rack::Utils.parse_query(@uri.query)
        @repo_id = nil#@prefix.split("/").last
        @prefix = parsed_query.delete("prefix") || ""
        @commit_sha = parsed_query.delete("commit_sha")
      end
    end

    def apply_prefix(path)
      if @prefix.to_s.size > 0
        File.join(@prefix, path)
      else
        path
      end
    end

    def find_paths(directory, extensions = "*.rb")
      all_paths = glob("#{directory}/**/#{extensions}") +
        glob("#{directory}/#{extensions}")

      reject_skipped_files(all_paths.sort.uniq)
    end

    def glob(pattern)
      matching_paths = file_index.keys.select do |path|
        File.fnmatch(apply_prefix(pattern), path)
      end
      matching_paths.map { |path| remove_prefix(path) }
    end

    def remove_prefix(path)
      if @prefix.size > 0
        Pathname.new(path).relative_path_from(Pathname.new(@prefix)).to_s
      else
        path
      end
    end

    def file_index
      @file_index ||= Hash.new.tap do |index|
        contents.each do |content|
          index[content.name] = content.id
        end
      end
    end

    def contents
      commit = grit_repo.commit(@commit_sha)
      tree_id = commit.tree.id
      output = grit_repo.git.native(:ls_tree, { r: true }, tree_id)
      grit_tree = ::Grit::Tree.allocate.construct_initialize(grit_repo, tree_id, output)
      grit_tree.contents
    end
  end
end
