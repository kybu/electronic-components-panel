require 'hatchet'

$uiLogger = nil

class UiLogger < Qt::Object
  include Hatchet::LevelManager
  attr_accessor :formatter

  signals 'logMessage(const QString &)'

  def initialize(parent=nil)
    super

    $uiLogger = self

    yield self if block_given?
  end

  def add(level, context, message)
    emit logMessage(@formatter.format(level, context, message))
  end
end

Hatchet.configure do |config|
  config.appenders << UiLogger.new do |appender|
    appender.level :debug
  end
end