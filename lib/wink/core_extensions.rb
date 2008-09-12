# Various extensions to core and library classes.

# TODO move gem declarations elsewhere
gem 'dm-core', '= 0.9.5'
gem 'dm-validations', '= 0.9.5'
gem 'dm-ar-finders', '= 0.9.5'
require 'dm-core'

require 'date'
require 'time'

class DateTime #:nodoc:
  # ISO 8601 formatted time value. This is 
  alias_method :iso8601, :to_s

  def inspect
    "#<DateTime: #{to_s}>"
  end
  def to_date
    Date.civil(year, mon, mday)
  end
  def to_time
    if self.offset == 0
      ::Time.utc(year, month, day, hour, min, sec)
    else
      new_offset(0).to_time
    end
  end
end

class Date #:nodoc:
  def inspect
    "#<Date: #{to_s}>"
  end
end

class Time
  def to_datetime
    jd = DateTime.civil_to_jd(year, mon, mday, DateTime::ITALY)
    fr = DateTime.time_to_day_fraction(hour, min, [sec, 59].min) +
           usec.to_r/86400000000
    of = utc_offset.to_r/86400
    DateTime.new!(DateTime.jd_to_ajd(jd, fr, of), of, DateTime::ITALY)
  end
end

require 'rack'

module Rack
  class Request

    # The IP address of the upstream-most client (e.g., the browser). This
    # is reliable even when the request is made through a reverse proxy or
    # other gateway.
    def remote_ip
      @env['HTTP_X_FORWARDED_FOR'] || @env['HTTP_CLIENT_IP'] || @env['REMOTE_ADDR']
    end

  end
end


require 'sinatra'

# The running environment as a Symbol; obtained from Sinatra's
# application options.
def environment
  Sinatra.application.options.env.to_sym
end

# Truthful when the application is in the process of being reloaded
# by Sinatra.
def reloading?
  Sinatra.application.reloading?
end
