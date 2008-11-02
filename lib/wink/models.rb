require 'wink'

require 'dm-core'
require 'dm-validations'
require 'dm-ar-finders'

class InvalidRecord < Exception
end

class Entry
  include DataMapper::Resource

  property :id, Integer, :serial => true

  property :slug, String, :size => 255, :nullable => false, :index => :unique
  property :type, Discriminator, :index => true
  property :published, Boolean, :default => false
  property :title, String, :size => 255, :nullable => false
  property :summary, Text, :lazy => false
  property :filter, String, :size => 20, :default => 'markdown'
  property :url, String, :size => 255
  property :created_at, DateTime, :nullable => false, :index => true
  property :updated_at, DateTime, :nullable => false
  property :body, Text

  validates_present :title, :slug, :filter

  has n, :comments,
    :spam.not => true,
    :order => [:created_at.asc]

  has n, :taggings
  has n, :tags, :through => :taggings

  before(:save) { self.updated_at = DateTime.now }

  def initialize(attributes={})
    self.created_at = DateTime.now
    self.updated_at = self.created_at
    self.filter = 'markdown'
    super
    yield self if block_given?
  end

  def stem
    "writings/#{slug}"
  end

  def permalink
    "#{Wink.url}/#{stem}"
  end

  def domain
    if url && url =~ /https?:\/\/([^\/]+)/
      $1.strip.sub(/^www\./, '')
    end
  end

  def created_at=(value)
    value = value.to_datetime if value.respond_to?(:to_datetime)
    attribute_set :created_at, value
  end

  def updated_at=(value)
    value = value.to_datetime if value.respond_to?(:to_datetime)
    attribute_set :updated_at, value
  end

  def published?
    !! published
  end

  def published=(value)
    value = ! ['false', 'no', '0', ''].include?(value.to_s)
    self.created_at = self.updated_at = DateTime.now if value && draft? && !new_record?
    attribute_set :published, value
  end

  def publish!
    self.published = true
    save
  end

  def draft?
    ! published
  end

  def body?
    ! body.blank?
  end

  def tag_names=(value)
    taggings.clear
    tag_names =
      if value.respond_to?(:to_ary)
        value.to_ary
      elsif value.nil?
        []
      elsif value.respond_to?(:to_str)
        value.split(/[\s,]+/)
      end
    tag_names.uniq.each { |tag_name| tag! tag_name }
  end

  def tag_names
    taggings.collect { |t| t.tag.name }
  end

  def tag!(tag_name)
    if tag = Tag.find_or_create(:name => tag_name)
      tagging = Tagging.new(:tag => tag)
      taggings << tagging
      # tags.reload!
      tagging
    end
  end

  def self.published(options={})
    options = { :order => [:created_at.desc], :published => true }.
      merge(options)
    all(options)
  end

  def self.drafts(options={})
    options = { :order => [:created_at.desc], :published => false }.
      merge(options)
    all(options)
  end

  def self.circa(year, options={})
    options = {
      :created_at.gte => Date.new(year, 1, 1),
      :created_at.lt => Date.new(year + 1, 1, 1),
      :order => [:created_at.asc]
    }.merge(options)
    published(options)
  end

  def self.tagged(tag, options={})
    if tag = Tag.first(:name => tag)
      tag.entries
    else
      []
    end
  end

  # The most recently published Entry (or specific subclass when called on
  # Article, Bookmark, or other Entry subclass).
  def self.latest(options={})
    first({ :order => [:created_at.desc], :published => true }.merge(options))
  end

  # XXX neither ::create or ::create! pass the block parameter to ::new

  def self::create(attributes={}, &block) #:nodoc:
    instance = new(attributes, &block)
    instance.save
    instance
  end

  def self::create!(attributes={}, &block) #:nodoc:
    instance = create(attributes, &block)
    raise InvalidRecord, instance.errors.inspect if instance.errors.any?
    instance
  end

end

class Article < Entry
end

class Bookmark < Entry

  def stem
    "linkings/#{slug}"
  end

  def filter
    'markdown'
  end

  # Synchronize bookmarks with del.icio.us. The :delicious configuration option
  # must be set to a two-tuple of the form: ['username','password']. Returns the
  # number of bookmarks synchronized when successful or nil if del.icio.us
  # synchronization is disabled.
  def self.synchronize(options={})
    return nil if Wink[:delicious].nil?
    options.each { |key,val| delicious.send("#{key}=", val) }
    count = 0

    delicious.synchronize :since => last_updated_at do |source|

      # skip URLs matching the delicious_filter regexp
      next if Wink.delicious_filter && source[:href] =~ Wink.delicious_filter

      # skip private bookmarks
      next unless source[:shared]

      bookmark = find_or_create(:slug => source[:hash])
      bookmark.attributes = {
        :url        => source[:href],
        :title      => source[:description],
        :summary    => source[:extended],
        :body       => source[:extended],
        :filter     => 'text',
        :created_at => source[:time].getlocal,
        :updated_at => source[:time].getlocal,
        :published  => 1
      }
      bookmark.tag_names = source[:tags]
      bookmark.save
      count += 1

      # HACK: DataMapper wants to overwrite the created_at date we
      # set explicitly when creating a new record.
      bookmark.created_at = source[:time].getlocal
      bookmark.save

    end

    count
  end

  def self.delicious
    require 'wink/delicious'
    connection = Wink::Delicious.new(*Wink[:delicious])
    (class <<self;self;end).send(:define_method, :delicious) { connection }
    connection
  end

  # The Time of the most recently updated Bookmark in UTC.
  def self.last_updated_at
    latest && latest.created_at
  end

end


class Tag
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :name, String, :nullable => false, :index => :unique
  property :created_at, DateTime, :nullable => false
  property :updated_at, DateTime, :nullable => false

  validates_is_unique :name
  alias_method :to_s, :name

  has n, :taggings
  has n, :entries,
    :through => :taggings,
    :conditions => { :published => true },
    :order => [:created_at.desc]

  # When key is a String or Symbol, find a Tag by name; when key is an
  # Integer, find a Tag by id.
  def self.[](key)
    case key
    when String, Symbol then first(:name => key.to_s)
    when Integer        then super
    else raise TypeError,    "String, Symbol, or Integer key expected"
    end
  end

  def initialize(*args)
    self.updated_at = DateTime.now
    self.created_at ||= self.updated_at
    super
  end

end


class Tagging
  include DataMapper::Resource

  property :id, Integer, :serial => true

  belongs_to :entry
  belongs_to :tag
end


class Comment
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :author, String, :size => 80
  property :ip, String, :size => 50
  property :url, String, :size => 255
  property :body, Text, :nullable => false, :lazy => false
  property :created_at, DateTime, :nullable => false, :index => true
  property :referrer, String, :size => 255
  property :user_agent, String, :size => 255
  property :checked, Boolean, :default => false
  property :spam, Boolean, :default => false, :index => true

  property :entry_id, Integer, :index => true
  belongs_to :entry

  validates_present :body, :entry_id

  before :create do
    check
  end

  def initialize(*args, &b)
    self.created_at = DateTime.now
    super
  end

  def self.ham(options={})
    all({:spam.not => true, :order => [:created_at.desc]}.merge(options))
  end

  def self.spam(options={})
    all({:spam => true, :order => [:created_at.desc]}.merge(options))
  end

  def excerpt(length=65)
    body.to_s.gsub(/[\s\r\n]+/, ' ')[0..length] + " ..."
  end

  def body=(text)
    # the first sub autolinks URLs when on line by itself; the second sub
    # disables escapes markdown's headings when followed by a number.
    text = text.to_s
    text.gsub!(/^https?:\/\/\S+$/, '<\&>')
    text.gsub!(/^(\s*)(#\d+)/) { [$1, "\\", $2].join }
    text.gsub!(/\r/, '')
    attribute_set :body, text
  end

  def url
    # TODO move this kind of logic into the setter
    return nil if attribute_get(:url).to_s.strip.blank?
    attribute_get(:url).to_s.strip
  end

  def author_link
    case url
    when nil                         then nil
    when /^mailto:.*@/, /^https?:.*/ then url
    when /@/                         then "mailto:#{url}"
    else                                  "http://#{url}"
    end
  end

  def author_link?
    !author_link.nil?
  end

  def author
    if (author = attribute_get(:author)).blank?
      'Anonymous Coward'
    else
      author
    end
  end

  # Check the comment with Akismet. The spam attribute is updated to reflect
  # whether the spam was detected or not.
  def check
    return true if checked
    self.checked = true
    self.spam = blacklisted? || akismet(:check) || false
  rescue => boom
    logger.error "An error occured while connecting to Akismet: #{boom.to_s}"
    self.checked = false
  end

  # Check the comment with Akismet and immediately save the comment.
  def check!
    check
    save
  end

  # True when the comment matches any of the blacklisted patterns.
  def blacklisted?
    Array(Wink.comment_blacklist).any? { |pattern| pattern === body }
  end

  # Has the current comment been marked as spam?
  def spam?
    !! spam
  end

  # Mark this comment as Spam and immediately save the comment. If Akismet is
  # enabled, the comment is submitted as spam.
  def spam!
    self.checked = self.spam = true
    akismet :spam!
    save
  end

  # Opposite of #spam? -- true when the comment has not been marked as
  # spam.
  def ham?
    ! spam
  end

  # Mark this comment as Ham and immediately save the comment. If Akismet is
  # enabled, the comment is submitted as Ham.
  def ham!
    self.checked, self.spam = true, false
    akismet :ham!
    save
  end

private

  # Should comments be checked with Akismet before saved?
  def akismet?
    Wink.akismet_key && (production? || Wink.akismet_always)
  end

  # Send an Akismet request with parameters from the receiver's model. Return
  # nil when Akismet is not enabled.
  def akismet(method, extra={})
    akismet_connection.__send__(method, akismet_params(extra)) if akismet?
  end

  # Build a Hash of Akismet parameters based on the properties of the receiver.
  def akismet_params(others={})
    { :user_ip            => ip,
      :user_agent         => user_agent,
      :referrer           => referrer,
      :permalink          => entry.permalink,
      :comment_type       => 'comment',
      :comment_author     => author,
      :comment_author_url => url,
      :comment_content    => body }.merge(others)
  end

  # The Wink::Akismet instance used for checking comments.
  def akismet_connection
    @akismet_connection ||=
      begin
        require 'wink/akismet'
        Wink::Akismet::new(Wink.akismet_key, Wink.akismet_url)
      end
  end

end
