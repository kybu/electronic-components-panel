require_relative 'helpers'

require 'Qt'

class SearchCache < Qt::Widget
  include WidgetHelpers

  slots 'supplierChanged(QObject *)', 'refreshCache()'
  signals 'cacheSelected(const QString &)'

  def initialize(parent=nil)
    super

    loadUi 'searchCache'
    layout.setContentsMargins 0, 0, 0, 0

    @cacheL = findChild Qt::ListWidget, 'searchCacheL'

    connect @cacheL, SIGNAL('itemDoubleClicked(QListWidgetItem *)') do |i|
      emit cacheSelected(i.text)
    end
  end

  def supplierChanged(supplier)
    refreshCache supplier
  end

  def refreshCache(supplier=$supplier)
    @cacheL.clear
    supplier.cache.each_key do |k|
      @cacheL.addItem(k) unless k =~ /_resultCount$/
    end
  end
end