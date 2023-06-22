# frozen_string_literal: true

class GitRepo
  attr_reader :path, :name

  def initialize(path, name = nil)
    @path = path
    @name = name
    @memoize = {}
  end

  def valid?
    File.exist?("#{path}/.git")
  end

  def url
    url = run("config --get remote.origin.url")
    return if url.blank?

    url.sub!(/\Agit@github\.com:/, "https://github.com/")
    url.sub!(/\.git\z/, "")
    url
  end

  def latest_local_commit
    run "rev-parse HEAD"
  end

  protected

  def run(cmd)
    @memoize[cmd] ||= begin
      return unless valid?
      cmd = "git #{cmd}".split(" ")
      Discourse::Utils.execute_command(*cmd, chdir: path).strip
    end
  rescue => e
    Discourse.warn_exception(e, message: "Error running git command: #{cmd} in #{path}")
  end
end
