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
require_relative 'logging'

require 'fileutils'

module FileHelpers
  def self.resetStats
    @stats = {size: 0}
  end

  def self.stats
    @stats
  end

  resetStats

  def self.deleteDir(dir)
    dir = [dir] if dir.kind_of? String

    dir.each do |d|
      if Dir.exists? d
        log.debug "Deleting the '#{d}' directory"

        Dir[d+'/**/*'].each {|f| updateStats f}

        FileUtils.rmtree d
      end
    end
  end

  def self.deleteFile(file)
    file = [file] if file.kind_of? String

    file.each do |f|
      if File.exists? f and File.file? f
        log.debug "Deleting the '#{f}' file"

        updateStats f
        FileUtils.rm f
      end
    end
  end

  private
  def self.updateStats(file)
    if File.file? file
      @stats[:size] += File.lstat(file).size
    end
  end

end