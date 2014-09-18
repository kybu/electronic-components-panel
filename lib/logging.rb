# Copyright 2014 Peter Vrabel <kybu@kybu.org>
# This file is part of 'Electronic Components Panel'.
#
# 'Electronic Components Panel' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# 'Electronic Components Panel' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with 'Electronic Components Panel'. If not, see <http://www.gnu.org/licenses/>.
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