require 'hatchet'

Hatchet.configure do |config|
  config.level :debug

  config.appenders << Hatchet::LoggerAppender.new do |a|
    a.logger = Logger.new $stdout
  end
end