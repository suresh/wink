require 'sinatra'
require 'haml'
require 'html5/html5parser'
require 'html5/sanitizer'

require 'wink'
require 'wink/models'
require 'wink/helpers'


# Bring Wink::Helpers into Sinatra
helpers { include Wink::Helpers }


# Resources =================================================================

get '/' do
  @title = wink.title
  @entries = Entry.published(:limit => 50)

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?

  haml :home
end

get Wink.writings_url do
  @title = wink.writings
  @entries = Article.published

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?

  haml :home
end

get Wink.linkings_url do
  @title = wink.linkings
  @entries = Bookmark.published(:limit => 100)

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?

  haml :home
end

get Wink.archive_url + ':year/' do
  @title = "#{wink.author} circa #{params[:year].to_i}"
  @entries = Entry.circa(params[:year].to_i)

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?

  haml :home
end

get Wink.tag_url + ':tag' do
  @title = "Regarding: '#{h(params[:tag].to_s.upcase)}'"
  @entries = Entry.tagged(params[:tag]).reject { |e| e.draft? }
  @entries.sort! do |b,a|
    case
    when a.is_a?(Bookmark) && !b.is_a?(Bookmark)  ; -1
    when b.is_a?(Bookmark) && !a.is_a?(Bookmark)  ;  1
    else a.created_at <=> b.created_at
    end
  end
  haml :home
end

get Wink.writings_url + ':slug' do
  @entry = Article.first(:slug => params[:slug])
  raise Sinatra::NotFound unless @entry

  require_administrative_privileges if @entry.draft?
  last_modified [@entry.updated_at, *@entry.comments.map{|e| e.created_at}].max

  @title = @entry.title
  @comments = @entry.comments

  haml :entry
end

get Wink.drafts_url do
  require_administrative_privileges
  @entries = Entry.drafts
  haml :home
end

get Wink.drafts_url + 'new' do
  require_administrative_privileges
  @title = 'New Draft'
  @entry = Article.new(
    :created_at => Time.now,
    :updated_at => Time.now,
    :filter => 'markdown'
  )
  haml :draft
end

post Wink.drafts_url do
  require_administrative_privileges
  @entry =
    if params[:id].blank?
      Article.new
    else
      Entry.get!(params[:id].to_i)
    end
  @entry.tag_names = params[:tag_names]
  @entry.attributes = params.to_hash
  @entry.save
  redirect entry_url(@entry)
end

get Wink.drafts_url + ':slug' do
  require_administrative_privileges
  @entry = Entry.first(:slug => params[:slug])
  raise Sinatra::NotFound unless @entry
  @title = @entry.title
  haml :draft
end

# Feeds ======================================================================

mime :atom, 'application/atom+xml'

get '/feed' do
  @title = wink.writings
  @entries = Article.published(:limit => 10)

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?
  content_type :atom, :charset => 'utf-8'

  builder :feed, :layout => :none
end

get Wink.linkings_url + 'feed' do
  @title = wink.linkings
  @entries = Bookmark.published(:limit => 30)

  last_modified @entries.map{|e| e.updated_at}.max if @entries.any?
  content_type :atom, :charset => 'utf-8'

  builder :feed, :layout => :none
end

get '/comments/feed' do
  @title = "Recent Comments"
  @comments = Comment.ham(:limit => 25)

  last_modified @comments.map{|c| c.created_at}.max if @comments.any?
  content_type :atom, :charset => 'utf-8'

  builder :comment_feed, :layout => :none
end

# Comments ===================================================================

get '/comments/' do
  @title = 'Recent Discussion'
  @comments = Comment.ham(:limit => 50)
  haml :comments
end

get '/spam/' do
  require_administrative_privileges
  @title = 'Spam'
  @comments = Comment.spam(:limit => 100)
  haml :comments
end

delete '/comments/:id' do
  require_administrative_privileges
  comment = Comment.get!(params[:id].to_i)
  raise Sinatra::NotFound if comment.nil?
  comment.destroy
  ''
end

put '/comments/:id' do
  require_administrative_privileges
  bad_request! if request.media_type != 'text/plain'
  comment = Comment.get!(params[:id].to_i)
  raise Sinatra::NotFound if comment.nil?
  comment.body = request.body.read
  comment.save!
  status 204
  ''
end

get '/comments/:id' do
  comment = Comment.get!(params[:id].to_i)
  raise Sinatra::NotFound if comment.nil?
  comment_body(comment)
end

post Wink.writings_url + ':slug/comment' do
  entry = Entry.first(:slug => params[:slug])
  raise Sinatra::NotFound if entry.nil?
  attributes = {
    :referrer    => request.referrer,
    :user_agent  => request.user_agent,
    :ip          => request.remote_ip,
    :body        => params[:body],
    :url         => params[:url],
    :author      => params[:author],
    :spam        => false
  }
  comment = entry.comments.create(attributes)
  if comment.spam?
    status 403
    haml :rickroll
  else
    redirect entry_url(entry) + "#comment-#{comment.id}"
  end
end

# Authentication and Authorization ===========================================

helpers do

  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
  end

  def unauthorized!(realm=wink.realm)
    header 'WWW-Authenticate' => %(Basic realm="#{realm}")
    throw :halt, [ 401, 'Authorization Required' ]
  end

  def bad_request!
    throw :halt, [ 400, 'Bad Request' ]
  end

  def authorized?
    request.env['REMOTE_USER']
  end

  def authorize
    credentials = [ wink.username, wink.password ]
    if auth.provided? && credentials == auth.credentials
      request.env['wink.admin'] = true
      request.env['REMOTE_USER'] = auth.username
    end
  end

  def require_administrative_privileges
    return if authorized?
    unauthorized! unless auth.provided?
    bad_request! unless auth.basic?
    unauthorized! unless authorize
  end

  def admin?
    authorized? || authorize
  end

end

get '/identify' do
  require_administrative_privileges
  redirect(params[:dest] || '/')
end
