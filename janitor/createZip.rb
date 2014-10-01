require_relative '../lib/helpers'
require_relative 'lib/fileHelpers'
require_relative 'lib/logging'

require 'fileutils'
require 'bundler'
require 'pp'
require 'archive/zip'

include Hatchet

scriptDir = (File.expand_path File.dirname(__FILE__)).gsub '\\', '/'
Dir.chdir scriptDir

rubyRoot =
    File.expand_path(
        File.dirname(Helpers.actualRubyExecutable)+'/..')

log.debug "Ruby root: #{rubyRoot}"

tmpDir = "#{scriptDir}/components"
if Dir.exists? tmpDir
  log.debug "Deleting the old '#{tmpDir}' directory"
  FileUtils.rmtree tmpDir
end
Dir.mkdir tmpDir

Dir.chdir tmpDir

#
# Prepare Ruby installation

Dir.mkdir 'r21'
log.debug "Copying the ruby installation"
FileUtils.cp_r rubyRoot+'/.', 'r21'
Dir.chdir 'r21' do

  FileHelpers.deleteDir %w{devkit doc share}
  FileHelpers.deleteFile %w{unins000.exe unins000.dat}
  FileHelpers.deleteFile Dir['lib/*.a']

  Dir.chdir "lib/ruby/gems/2.1.0" do
    FileHelpers.deleteDir %w{cache doc}
  end

  # Use Bundler data to only keep gems and their dependencies which are specified in Gemfile.
  Dir.chdir 'lib/ruby/gems/2.1.0/gems' do
    FileHelpers.resetStats

    gems = Bundler.load.specs.sort.map {|s| File.basename s.full_gem_path}

    toDelete = Dir['*'].select do |d|
      File.directory?(d) and not gems.include?(d)
    end

    FileHelpers.deleteDir toDelete

    # Clean up the Qt gems
    log.info 'Cleaning up the Qt gems'

    FileHelpers.deleteFile Dir['qtbindings*/**/*webkit*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*designer*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*declarative*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*phonon*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*sqlite*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*sqlodbc*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*dbus*']
    FileHelpers.deleteFile Dir['qtbindings*/**/*script*']

    qtGemDir = gems.find {|g| g =~ /^qtbindings-\d/i}
    Dir.chdir qtGemDir do
      FileHelpers.deleteDir %w{bin/2.0 bin/2.1 examples lib/2.0}
    end

    # Delete all source code files and object files
    FileHelpers.deleteFile Dir['**/*.{o,c,h}']

    # Clean up the FFI gem
    FileHelpers.deleteDir Dir['ffi-*/ext/ffi_c/libffi*']

    FileHelpers.deleteDir Dir['**/.yardoc']

    log.info "#{FileHelpers.stats[:size]/1024}KB deleted from the gems"
  end

end

#
# Prepare the app itself

FileUtils.mkdir_p 'app'

Dir.chdir(File.expand_path(File.dirname(__FILE__)+'/..')) do
  # Get the list of all app files managed by Mercurial
  toCopy = `hg status -cma`.each_line.map { |l| l[2..-1].chomp.gsub '\\', '/' }

  toCopy.each do |f|
    FileUtils.mkdir_p(tmpDir+'/app/'+File.dirname(f))

    FileUtils.cp f, tmpDir+'/app/'+f
  end
end

File.write 'run.bat', 'r21\bin\ruby.exe app\components.rb'

Dir.chdir '..'

# Create the zip file
log.info "Going to create the zip file"
FileUtils.rm_f 'components.zip'
Archive::Zip.archive 'components.zip', 'components'

log.info "Done"


