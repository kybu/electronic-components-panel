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
require 'httparty'
require 'xmlsimple'

require_relative 'logging'
require_relative 'helpers'
require_relative 'farnell'

class TableEventFilter < Qt::Object
  signals 'productRightClick(int)' # productsData index

  def eventFilter(obj, e)
    if e.type == Qt::Event::ContextMenu
      if obj.currentItem
        emit(
          productRightClick(
            obj.item(obj.currentRow, 0)
              .data(Qt::UserRole).toInt))
      end

      return true
    end

    return false
  end
end

class Main < Qt::Widget
  include WidgetHelpers
  include Hatchet

  slots 'filterActivated(QWidget *)', 'filterDeactivated(QWidget *)',
            'searchFor(const QString &)', 'supplierChanged(QObject *)'

  signals 'search(QString *)',
                'supplierChanged(QObject *)',
                'productRightClick(QObject *)'

  def initialize(parent=nil)
    super

    loadUi 'main'

    @productsData = []
    @activeFilters = []

    @searchFor = findChild Qt::LineEdit, 'searchInputL'
    @filter = findChild Qt::LineEdit, 'filterL'

    @productsT = findChild Qt::TableWidget, 'productsT'
    @resultCount = findChild Qt::Label, 'resultCountL'
    @shopL = findChild Qt::Label, 'shopL'
    @cacheL = findChild Qt::ListWidget, 'cacheL'

    @productInfoGroup = findChild Qt::GroupBox, 'productInfoG'
    @productInfoGroup.hide
    @productInfo = findChild Qt::Label, 'productInfoL'

    @tableEventFilter = TableEventFilter.new
    @productsT.setColumnWidth 0, 400
    connect @tableEventFilter, SIGNAL('productRightClick(int)') do |i|
      product = ProductHolder.new @productsData[i]
      emit productRightClick(product)

      product.dispose
    end

    connect @searchFor, SIGNAL('returnPressed()') do searchFor end
    connect @filter, SIGNAL('returnPressed()') do filter end

    connect @productsT, SIGNAL('itemDoubleClicked(QTableWidgetItem *)') do |i|
      dataIndex = i.data(Qt::UserRole).toInt

      data = @productsData[dataIndex]
      pp data

      attrText = ''
      data['attributes'].each do |attr|
        attrText += "#{attr['attributeLabel']}: #{attr['attributeValue'][0..200]}\n"
      end
      @productInfo.setText attrText

      @productInfoGroup.show

#      puts "http://uk.farnell.com/productimages/farnell/standard#{data['image']['baseName']}"
#
#      picData = HTTParty.get("http://uk.farnell.com/productimages/farnell/standard#{data['image']['baseName']}").parsed_response
#
#      picFile = '.'+data['image']['baseName']
#      File.binwrite picFile, picData
#
#      pix = Qt::Pixmap.new picFile
#
#      @productImage.setPixmap pix
    end
  end

  def filterActivated(filter)
    @activeFilters << filter

    applyFilters
  end

  def filterDeactivated(filter)
    @activeFilters.delete filter

    applyFilters
  end

  def filter
    data = $supplier.filter(@filter.text)

    fillProducts(data)
  end

  def searchFor(search=nil)
    query = search || @searchFor.text
    @searchFor.setText query

    resultCount = $supplier.resultCount query
    @resultCount.setText "Result: #{resultCount}"

    products = $supplier.searchFor query, resultCount

    fillProducts products

    emit search(@searchFor.text)
  end

  def supplierChanged(supplier)
    @shopL.setText 'Shop: '+supplier.id
    clearProductsTable
  end

  private

  def applyFilters
    clearProductsTable

    filteredProducts = []
    $supplier.fetchCache($supplier.lastQuery).each do |p|
      ok = @activeFilters.reduce(true) {|m, f| m and f.eval p}
      filteredProducts << p if ok
    end

    fillProducts filteredProducts
  end

  def clearProductsTable
    @productsT.setSortingEnabled false
    @productsT.clearContents
    @productsT.setRowCount 0
    @productsT.setColumnCount 4

    @resultCount.setText 'Results: -'
  end

  def fillProducts(products)
    @productsT.blockSignals true

    begin
      clearProductsTable
      return if products.nil? or products.empty?

      @productsData = products

      @resultCount.setText "Result: #{products.size}"

      row = 0
      @productsT.setSortingEnabled false
      @productsT.setRowCount products.size

      items = []
      products.each do |p|
        row += 1

        i = Qt::TableWidgetItem.new(p['displayName'].to_s)
        i.setData(Qt::UserRole, qVariantFromValue(row-1))
        items << i

        @productsT.setItem(
            row-1, 0,
            i)

        minQuant = p['translatedMinimumOrderQuality'].to_i
        i1 = Qt::TableWidgetItem.new(minQuant.to_s)
        i1.setData(Qt::UserRole, qVariantFromValue(row-1))
        items << i1

        @productsT.setItem(
            row-1, 1,
            i1)

        price = p['prices'].is_a?(Array) ?
            p['prices'][0]['cost'].to_f
        :
            p['prices']['cost'].to_f

        i2 = Qt::TableWidgetItem.new price.to_s
        i2.setData Qt::UserRole, qVariantFromValue(row-1)
        items << i2

        @productsT.setItem row-1, 2, i2

        i3 = Qt::TableWidgetItem.new (minQuant*price).to_s
        i3.setData Qt::UserRole, qVariantFromValue(row-1)
        items << i3

        @productsT.setItem row-1, 3, i3
      end

      if products.size != 0
        @productsT.setCurrentCell 0, 0
        @productsT.sortItems 0
        @productsT.setSortingEnabled true
      end

    ensure
      @productsT.installEventFilter(@tableEventFilter)
      @productsT.blockSignals false
    end
  end
end
