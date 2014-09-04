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