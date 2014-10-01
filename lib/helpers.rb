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
require 'Qt'
require 'qtuitools'
require 'ffi'
require 'base64'

module WidgetHelpers
  def loadUi(uiFile)
    loader = Qt::UiLoader.new

    (file = Qt::File.new File.dirname(__FILE__)+"/../ui/#{uiFile}.ui").open Qt::File::ReadOnly
    @ui = loader.load file, self
    file.dispose

    self.layout.dispose if self.layout != nil

    self.layout = Qt::VBoxLayout.new do |l|
      l.addWidget @ui
    end

    Qt::MetaObject.connectSlotsByName self
  end
end

module Base64Helpers
  extend self

  def to64(str)
    Base64.strict_encode64 str
  end

  def from64(str)
    Base64.strict_decode64 str
  end
end

# So that it can be used by signals / slots.
class ProductHolder < Qt::Object
  attr_accessor :product

  def initialize(product)
    super(nil)
    @product = product
  end
end

# So that it can be used by signals / slots.
class ProductsHolder < Qt::Object
  attr_accessor :products

  def initialize(products)
    super(nil)
    @products = products
  end
end

module Helpers
  extend FFI::Library
  ffi_lib :kernel32

  typedef :uintptr_t, :hmodule
  typedef :ulong, :dword
  typedef :uintptr_t, :handle

  attach_function :GetModuleHandle, :GetModuleHandleA, [:string], :hmodule
  attach_function :GetModuleFileName, :GetModuleFileNameA, [:hmodule, :pointer, :dword], :dword

  def self.actualRubyExecutable
    processHandle = GetModuleHandle nil

    rubyPath = FFI::MemoryPointer.new 1000
    rubyPathSize = GetModuleFileName processHandle, rubyPath, 999

    rubyPath.read_string rubyPathSize
  end

  attach_function :GetCurrentProcess, [], :handle

  ffi_lib :Userenv
  attach_function :GetUserProfileDirectory, :GetUserProfileDirectoryA, [
                         :handle, :pointer, :pointer], :bool

  ffi_lib :Advapi32
  attach_function :OpenProcessToken, [:handle, :dword, :pointer], :bool
  TOKEN_READ = 131080

  # TODO Proper buffer handling
  def self.userProfileDir
    # return ENV['USERPROFILE'] if ENV.has_key? 'USERPROFILE'

    processHandle = GetCurrentProcess()
    tokenHandleP = FFI::MemoryPointer.new :uintptr_t
    OpenProcessToken(processHandle, TOKEN_READ, tokenHandleP)

    bytes = FFI::MemoryPointer.new :ulong
    buffer = FFI::MemoryPointer.new 1000
    bytes.write_long 1000

    GetUserProfileDirectory(
        tokenHandleP.read_long,
        buffer, bytes)

    return buffer.read_string
  end

  def self.appData
    (userProfileDir+'/AppData/Roaming').gsub '\\', '/'
  end
end

# TODO: make it a mixin to the IO object
module PipeHelpers
  extend FFI::Library

  ffi_lib :kernel32, :msvcrt

  typedef :uintptr_t, :hmodule
  typedef :ulong, :dword
  typedef :uintptr_t, :handle

  attach_function :PeekNamedPipe, [
      :handle, :pointer, :dword, :pointer, :pointer, :pointer], :bool
  attach_function :_get_osfhandle, [:dword], :dword

  def self.availBytes(io)
    handle = _get_osfhandle io.fileno
    bytes = FFI::MemoryPointer.new :ulong

    ok = PeekNamedPipe handle, nil, 0, nil, bytes, nil

    return bytes.read_ulong
  end
end