require_relative 'helpers'

require 'fileutils'

APPDATA = (Helpers.appData+'/kybu/components').gsub '\\', '/'

unless File.directory? APPDATA
  FileUtils.mkdir_p APPDATA
end