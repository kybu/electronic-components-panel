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

# So that it can be used by signals / slots.
class ProductHolder < Qt::Object
  attr_accessor :product

  def initialize(product)
    super(nil)
    @product = product
  end
end

module Helpers
  extend FFI::Library
  ffi_lib :kernel32

  typedef :uintptr_t, :hmodule
  typedef :ulong, :dword

  attach_function :GetModuleHandle, :GetModuleHandleA, [:string], :hmodule
  attach_function :GetModuleFileName, :GetModuleFileNameA, [:hmodule, :pointer, :dword], :dword

  def self.actualRubyExecutable
    processHandle = GetModuleHandle nil

    rubyPath = FFI::MemoryPointer.new 1000
    rubyPathSize = GetModuleFileName processHandle, rubyPath, 999

    rubyPath.read_string rubyPathSize
  end
end