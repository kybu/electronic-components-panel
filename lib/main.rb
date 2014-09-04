require 'Qt'
require 'qtuitools'
require 'httparty'
require 'xmlsimple'

require_relative 'logging'
require_relative 'helpers'
require_relative 'farnell'

class Main < Qt::Widget
  include WidgetHelpers
  include Hatchet

  slots 'filterActivated(QWidget *)', 'filterDeactivated(QWidget *)',
        'searchFor(const QString &)'
  signals 'search(QString *)', 'supplierChanged(QObject *)'

  def initialize(parent=nil)
    super

    loadUi 'main'

    @productsData = []
    @activeFilters = []

    @supplier = $farnell

    @searchFor = findChild Qt::LineEdit, 'searchInputL'
    @filter = findChild Qt::LineEdit, 'filterL'

    @productsT = findChild Qt::TableWidget, 'productsT'
    @resultCount = findChild Qt::Label, 'resultCountL'
    @cacheL = findChild Qt::ListWidget, 'cacheL'

    @productInfoGroup = findChild Qt::GroupBox, 'productInfoG'
    @productInfoGroup.hide
    @productInfo = findChild Qt::Label, 'productInfoL'

    @farnellSupplierRB = findChild Qt::RadioButton, 'farnellRB'
    @cpcSupplierRB = findChild Qt::RadioButton, 'cpcRB'

    @farnellSupplierRB.setChecked true

    @productsT.setColumnWidth 0, 400

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

    connect @farnellSupplierRB, SIGNAL('toggled(bool)') do
      @supplier = $farnell
      clearProductsTable

      emit supplierChanged(@supplier)
    end
    connect @cpcSupplierRB, SIGNAL('toggled(bool)') do
      @supplier = $cpc
      clearProductsTable

      emit supplierChanged(@supplier)
    end
  end

  def refresh
    emit supplierChanged(@supplier)
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
    data = @supplier.filter(@filter.text)

    fillProducts(data)
  end

  def searchFor(search=nil)
    query = search || @searchFor.text
    @searchFor.setText(query)

    resultCount = @supplier.resultCount query
    @resultCount.setText "Result: #{resultCount}"

    products = @supplier.searchFor query, resultCount

    fillProducts products

    emit search(@searchFor.text)
  end

  private

  def applyFilters
    clearProductsTable

    filteredProducts = []
    @supplier.fetchCache(@supplier.lastQuery).each do |p|
      ok = @activeFilters.reduce(true) {|m, f| m and f.eval p}
      filteredProducts << p if ok
    end

    fillProducts filteredProducts
  end

  def clearProductsTable
    @productsT.setSortingEnabled false
    @productsT.setRowCount 0
  end

  def fillProducts(products)
    clearProductsTable
    return if products.nil? or products.empty?

    @productsData = products

    @resultCount.setText "Result: #{products.size}"

    row = 0
    @productsT.setSortingEnabled false
    @productsT.setRowCount products.size

    products.each do |p|
      row += 1

      i = Qt::TableWidgetItem.new(p['displayName'])
      i.setData(Qt::UserRole, qVariantFromValue(row-1))

      @productsT.setItem(
        row-1, 0,
        i)

      minQuant = p['translatedMinimumOrderQuality'].to_i
      i = Qt::TableWidgetItem.new(minQuant.to_s)
      i.setData(Qt::UserRole, qVariantFromValue(row-1))

      @productsT.setItem(
        row-1, 1,
        i)

      price = p['prices'].is_a?(Array) ?
        p['prices'][0]['cost'].to_f
          :
        p['prices']['cost'].to_f

      i = Qt::TableWidgetItem.new(price.to_s)
      i.setData(Qt::UserRole, qVariantFromValue(row-1))

      @productsT.setItem(
        row-1, 2,
        i)

      i = Qt::TableWidgetItem.new((minQuant*price).to_s)
      i.setData(Qt::UserRole, qVariantFromValue(row-1))

      @productsT.setItem(
        row-1, 3,
        i)
    end
    @productsT.setSortingEnabled true
  end
end
