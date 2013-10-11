require 'brakeman/smoke_client'

class GritRepo
  def initialize(uri, repo_id)
    @uri = uri
    @repo_id = repo_id
  end

  def repo
    grit_repo
  end

private
  def grit_repo
    @grit_repo ||= ::Grit::Repo.allocate.tap do |r|
      r.path = "#{@repo_id}.git"

      if @uri.scheme == "git"
        r.git = ::Grit::Git.new(@uri.path)
      else
        r.git = SmokeClient.new(@uri) 
      end
    end
  end
end
