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
require_relative 'logging'
require_relative 'helpers'
require_relative 'farnell'
require_relative 'comm'

require 'Qt'
require 'qtuitools'
require 'httparty'
require 'xmlsimple'
require 'win32/process'
require 'childprocess'

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

class QueryProcess < Qt::Object
  include Base64Helpers

  attr_reader :process

  signals 'searchResultsFromCache()',
               'products(QObject *)',
               'numberOfProducts(int)',
               'productsFetched(int)'

  def initialize(storeId, query)
    super nil

    @msg = CommMsgs::TransportMsg.streamed
    @rawData = ''
    @receivedBytes = 0

    @process = ChildProcess.build(
        Helpers.actualRubyExecutable, $0,
        '-q', storeId, query)

    @r, @w = IO.pipe
    @process.io.stdout = @w
  end

  def start
    @process.start
    @w.close
  end

  def receiveStream(opts = {})
    opts[:maxTime] ||= 0.173
    t1 = Time.now

    while (
        ((bytes = PipeHelpers.availBytes @r) > 0 or not @rawData.empty?) and
        (opts[:drain] or Time.now - t1 < opts[:maxTime]))

      if bytes > 0
        @rawData += @r.readpartial bytes
        @receivedBytes += bytes
      end

      @rawData = @msg.received @rawData

      if msgAvailable?
        msg = @msg.toMsg
        @msg.clear

        case msg.type

          when CommMsgs::NumberOfProducts::ID
            emit numberOfProducts(msg.numberOfProducts.count)

          when CommMsgs::ProductsFetched::ID
            emit productsFetched(msg.productsFetched.count)

          when CommMsgs::SearchResultsFromCache::ID
            emit searchResultsFromCache()

          when CommMsgs::CommIssues::ID
            puts msg.commIssues.issue

          when CommMsgs::Products::ID
            h = ProductsHolder.new(
                Marshal.load(msg.products.data))
            emit products(h)
            h.dispose

        end
      end
    end
  end

  def done?
    return false if @process.alive?

    receiveStream drain: true
    return true
  end

  def msgAvailable?
    @msg.received?
  end

end

class Main < Qt::Widget
  include WidgetHelpers
  include Hatchet

  slots 'filterActivated(QWidget *)', 'filterDeactivated(QWidget *)',
            'searchFor(const QString &)', 'supplierChanged(QObject *)',

            'resultCount(int)', 'searchResultProducts(QObject *)',

            'progressBarMax(int)', 'queryProgress(int)'

  signals 'searchStarted(const QString &)', 'search(QString *)', 'searchCancelled()',
               'supplierChanged(QObject *)',
               'productRightClick(QObject *)'

  def initialize(parent=nil)
    super

    loadUi 'main'

    @queryProcess = nil
    @payload = ''

    @productsData = []
    @activeFilters = []

    @searchFor = findChild Qt::LineEdit, 'searchInputL'
    @textSearchL = findChild Qt::LineEdit, 'textSearchL'

    @productsT = findChild Qt::TableWidget, 'productsT'
    @resultCount = findChild Qt::Label, 'resultCountL'
    @shopL = findChild Qt::Label, 'shopL'
    @cacheL = findChild Qt::ListWidget, 'cacheL'

    @productInfoGroup = findChild Qt::GroupBox, 'productInfoG'
    @productInfoGroup.hide
    @productInfo = findChild Qt::Label, 'productInfoL'
    @productPic = findChild Qt::Label, 'productPictureL'
    @productInfoLO = findChild Qt::HBoxLayout, 'productInfoLO'

    #
    # Query progress

    @cancelQueryPB = findChild Qt::PushButton, 'cancelQueryPB'
    @queryPB = findChild Qt::ProgressBar, 'queryPB'
    @progressWidgetHolder = findChild Qt::Widget, 'progressWidgetHolder'
    @progressWidgetHolder.hide

    connect @cancelQueryPB, SIGNAL('clicked()') do cancelQuery end


    @tableEventFilter = TableEventFilter.new
    @productsT.setColumnWidth 0, 400
    connect @tableEventFilter, SIGNAL('productRightClick(int)') do |i|
      product = ProductHolder.new @productsData[i]
      emit productRightClick(product)

      product.dispose
    end

    connect @searchFor, SIGNAL('returnPressed()') do searchFor end
    connect @textSearchL, SIGNAL('returnPressed()') do textSearch end

    connect @productsT, SIGNAL('itemDoubleClicked(QTableWidgetItem *)') do |i|
      dataIndex = i.data(Qt::UserRole).toInt

      data = @productsData[dataIndex]
      pp data

      attrText = data['displayName']+"\n\n"
      data['attributes'].each do |attr|
        attrText += "#{attr['attributeLabel']}: #{attr['attributeValue'][0..200]}\n"
      end
      @productInfo.setText attrText


      resp = HTTParty.get(
          "http://#{$supplier.id}/productimages/#{data['image']['vrntPath']}standard/#{data['image']['baseName']}")
      (pix = Qt::Pixmap.new).loadFromData resp.body, resp.size
      @productPic.setPixmap pix

      @productInfoGroup.show
      @productInfoLO.update

    end
  end

  def timerEvent(e)
    @queryProcess.receiveStream

   if @queryProcess.done?
      killTimer e.timerId
    end
  end

  def resultCount(count)
    @resultCount.setText "Result: #{count}"
  end

  def searchResultProducts(products)
    @searchResultsFromCache = false

    p = products.products
    fillProducts p

    @progressWidgetHolder.hide
    @lastQuery = @searchFor.text

    searchRelatedWidgets :enable

    $supplier.loadCache @lastQuery

    emit search(@searchFor.text)
  end

  def filterActivated(filter)
    @activeFilters << filter

    applyFilters
  end

  def filterDeactivated(filter)
    @activeFilters.delete filter

    applyFilters
  end

  def textSearch
    @activeFilters.delete_if {|f| f.kind_of? TextFilter}

    unless @textSearchL.text.empty?
      filterActivated TextFilter.new @textSearchL.text
    else
      applyFilters
    end
  end

  def searchFor(search=nil)
    query = search || @searchFor.text
    @searchFor.setText query

    @searchResultsFromCache = false

    emit searchStarted(query)

    @queryProcess = QueryProcess.new $supplier.id, query
    connect(
        @queryProcess, SIGNAL('products(QObject *)'),
        self, SLOT('searchResultProducts(QObject *)'))
    connect(
        @queryProcess, SIGNAL('numberOfProducts(int)'),
        self, SLOT('progressBarMax(int)'))
    connect @queryProcess, SIGNAL('productsFetched(int)') do |fetched|
      @queryPB.setValue @queryPB.value+fetched
    end

    connect @queryProcess, SIGNAL('searchResultsFromCache()') do
      @searchResultsFromCache = true
    end

    @queryProcess.start
    @queryPB.setValue 0
    @progressWidgetHolder.show
    searchRelatedWidgets :disable

    startTimer 700
  end

  def cancelQuery
    @cancelQueryPB.setEnabled false

    begin
      @queryProcess.process.stop
      @queryProcess.process.wait
    rescue ChildProcess::Error
    end

    @progressWidgetHolder.hide
    @cancelQueryPB.setEnabled true
    searchRelatedWidgets :enable

    emit searchCancelled()
  end

  def progressBarMax(max)
    if @searchResultsFromCache
      @queryPB.setMaximum max
    else
      @queryPB.setMaximum max*2
    end
  end

  def queryProgress(prog)
    @queryPB.setValue prog
  end

  def supplierChanged(supplier)
    @shopL.setText 'Shop: '+supplier.id
    clearProductsTable
  end

  private

  def searchRelatedWidgets(action = :disable)
    if action == :disable
      @searchFor.setEnabled false
      @textSearchL.setEnabled false
      @productsT.setEnabled false

    else
      @searchFor.setEnabled true
      @textSearchL.setEnabled true
      @productsT.setEnabled true
    end
  end

  def applyFilters
    clearProductsTable

    filteredProducts = []
    $supplier.fetchCache(@lastQuery).each do |p|
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

        i3 = Qt::TableWidgetItem.new("%0.2f" % (minQuant*price))
        i3.setData Qt::UserRole, qVariantFromValue(row-1)
        items << i3

        @productsT.setItem row-1, 3, i3
      end

      if products.size != 0
        @productsT.sortItems 0
        @productsT.setSortingEnabled true
        @productsT.setCurrentCell 0, 0
      end

    ensure
      @productsT.installEventFilter(@tableEventFilter)
      @productsT.blockSignals false
    end


  end
end
