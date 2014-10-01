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