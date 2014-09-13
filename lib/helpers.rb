require 'Qt'
require 'qtuitools'

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