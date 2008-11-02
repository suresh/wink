# The site's root URL. Note: the trailing slash should be
# omitted when setting this option.
set :url, 'http://localhost:4567'

# The full name of the site's author.
set :author, 'Anonymous Coward'

# The administrator username. You will be prompted to authenticate with
# this username before modifying entries and comments or providing other
# administrative activities. Default: "admin".
set :username, 'admin'

# The administrator password (see #username). The password is +nil+ by
# default, disabling administrative access; you must set the password
# explicitly.
set :password, nil

# The site's Akismet key, if spam detection should be performed.
set :akismet_key, nil

# The URL of the site as registered with Akismet. Defaults to the
# +url+ option.
set :akismet_url, nil

# Boolean specifying whether Akismet checks should be performed in all
# environments. Default is to check w/ Akismet only when in production
# environment.
set :akismet_always, false

# A del.icio.us username/password as a two-tuple: ['username', 'password'].
# When set, del.icio.us bookmark synchronization may be performed by calling
# Bookmark.synchronize!
set :delicious, nil

# A regular expression that matches URLs to your site's content. Used
# to detect bookmarks and external content referencing the current site.
set :delicious_filter, nil

# Where to write log messages.
set :log_stream, STDERR

# The site's title. Defaults to the author's name.
set :title, nil

# Title of area that lists Article entries.
set :writings, 'Writings'

# Title of area that lists Bookmark entries.
set :linkings, 'Linkings'

# Start date for archives + copyright notice.
set :begin_date, Date.today.year

# List of filters to apply to comments.
set :comment_filters, [:markdown, :sanitize]

# List of patterns that should cause a comment to be marked as spam. The
# blacklist check occurs before akismet checking.
set :comment_blacklist, nil

# Enable verbose trace logging
set :verbose, false

# URL mappings for various sections of the site
set :writings_url, "/writings/"
set :linkings_url, "/linkings/"
set :archive_url , "/circa/"
set :tag_url     , "/topics/"
set :drafts_url  , "/drafts/"
