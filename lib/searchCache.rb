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

  def contextMenuEvent(e)
    menu = Qt::Menu.new self

    aSelected = menu.addAction '&Delete selected cache'
    aAll = menu.addAction 'Delete &all cache'

    aSelected.setEnabled false if @cacheL.selectedItems.size == 0
    aAll.setEnabled false unless @cacheL.count > 0

    connect aSelected, SIGNAL('triggered()') do
      $supplier.deleteCache @cacheL.currentItem.text
      $supplier.loadCache
      refreshCache
    end

    connect aAll, SIGNAL('triggered()') do
      $supplier.deleteCache
      $supplier.loadCache
      refreshCache
    end

    menu.exec e.globalPos
  end
end