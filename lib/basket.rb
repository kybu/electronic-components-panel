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

class BasketInfo < Qt::Widget
  include WidgetHelpers

  slots 'basketUpdated()'
  signals 'showCompleteBasket()'

  def initialize(basket)
    super(nil)

    @basket = basket
    loadUi 'basketInfo'

    @totalL = findChild Qt::Label, 'totalL'
    @itemsL = findChild Qt::Label, 'itemsL'
    @showBasketL = findChild Qt::Label, 'showBasketL'

    connect @showBasketL, SIGNAL('linkActivated(const QString &)') do
      emit showCompleteBasket()
    end
  end

  def basketUpdated
    @totalL.setText "Total: #{@basket.totalStr}"
    @itemsL.setText "Products: #{@basket.size}"
  end
end

# Not meant to be used standalone. It is tailored to be used by the Basket class.
class BasketItemGrid < Qt::Widget
  include WidgetHelpers

  slots 'deleteAll()'
  signals 'quantityChanged(int, int)', # productIndex, quantity
          'deleted(int)' # productIndex

  Item = Struct.new(
      :productIndex, :displayName,
      :quantLayoutLE, :quantLayoutL, :quantLayout,
      :price, :totalPrice, :delete)

  def initialize(parent=nil)
    super

    @itemGrid = Qt::GridLayout.new
    setLayout @itemGrid
    initItemGrid

    @items = []
    @toDelete = []

    startTimer 1000*60
  end

  def timerEvent(e)
    @toDelete.each do |item|
      item.each {|w| w.dispose if w.is_a? Qt::Object}
    end
    @toDelete.clear
  end

  def deleteAll
    while (i=@items.pop)
      deleteItem i, :noSignals
    end
  end

  def addItem(product)
    item = Item.new

    item.productIndex = @items.size
    item.displayName = Qt::Label.new(product['displayName'])

    @itemGrid.addWidget(
        item.displayName,
        @itemGrid.rowCount, 0)

    # Quantity input
    layout = Qt::HBoxLayout.new do |l|
      l.addStretch 1

      l1 = Qt::Label.new(product.minQuant.to_s+"x")

      item.quantLayoutL = l1
      l.addWidget l1
    end

    v = Qt::IntValidator.new
    v.setBottom 1

    le = Qt::LineEdit.new {|l|
      l.setAlignment Qt::AlignHCenter }
    le.setValidator v
    le.setText product['basketQuantity'].to_s
    le.setFixedWidth 41
    le.setProperty 'productIndex', qVariantFromValue(item.productIndex)

    item.quantLayoutLE = le
    layout.addWidget le

    connect le, SIGNAL('textEdited(const QString &)') do |t|
      emit quantityChanged(le.property('productIndex').toInt, t.to_i)
    end

    @itemGrid.addLayout(
        layout,
        @itemGrid.rowCount-1, 1)

    item.quantLayout = layout

    # Price
    item.price = Qt::Label.new(product.price.to_s) do |l|
      l.setAlignment Qt::AlignRight | Qt::AlignVCenter
    end

    @itemGrid.addWidget(
        item.price,
        @itemGrid.rowCount-1, 2)

    # Total price
    item.totalPrice = Qt::Label.new(product.totalPriceStr) do |l|
      l.setAlignment Qt::AlignRight | Qt::AlignVCenter
    end

    @itemGrid.addWidget(
        item.totalPrice,
        @itemGrid.rowCount-1, 3)

    # Delete
    item.delete = Qt::PushButton.new(Qt::Icon.new('pics/cross.png'), '') do |b|
      b.setFlat(true)
    end

    connect(item.delete, SIGNAL('clicked()')) { deleteItem item}

    @itemGrid.addWidget(
        item.delete,
        @itemGrid.rowCount-1, 4)

    @items << item
  end

  def updateProduct(productIndex, product)
    @items[productIndex].quantLayoutLE.setText product['basketQuantity'].to_s
    @items[productIndex].totalPrice.setText product.totalPriceStr
  end

  private
  def initItemGrid
    l = @itemGrid
    l.addWidget(
        Qt::Label.new('<b>Product</b>'),
        0, 0)
    l.addWidget(
        Qt::Label.new('<b>Quantity</b>') {|l|
          l.setAlignment Qt::AlignHCenter },
        0, 1)
    l.addWidget(
        Qt::Label.new('<b>Price</b>') {|l|
          l.setAlignment Qt::AlignHCenter },
        0, 2)
    l.addWidget(
        Qt::Label.new('<b>Total price</b>') {|l|
          l.setAlignment Qt::AlignHCenter },
        0, 3)

    l.setColumnStretch 0, 1
    l.setColumnStretch 1, 0
    l.setColumnStretch 2, 0
    l.setColumnStretch 3, 0
  end

  def deleteItem(item, opts = nil)
    if $qApp.focusWidget
      $qApp.focusWidget.clearFocus
    end

    @toDelete << item

    item.displayName.hide
    item.price.hide
    item.totalPrice.hide
    item.delete.hide

    item.quantLayoutLE.hide
    item.quantLayoutL.hide

    @items.delete item

    emit deleted(item.productIndex) unless opts == :noSignals
  end
end

class Basket < Qt::Widget
  include WidgetHelpers

  attr_reader :items

  signals 'closeBasket()', 'basketUpdated()'
  slots   'add(QObject *)'

  QUICK_PASTE_LINK = '<a href="quickPaste://">Quick paste</a>'
  SHOW_BASKET_LINK = '<a href="showBasket://">Show basket</a>'

  def initialize
    super

    @items = []

    loadUi 'basket'

    @totalL = findChild Qt::Label, 'totalL'
    @itemsL = findChild Qt::Label, 'itemsL'
    @closeBasketL = findChild Qt::Label, 'closeBasketL'
    @quickPasteL = findChild Qt::Label, 'quickPasteL'
    @itemsArea = findChild Qt::ScrollArea, 'itemsArea'
    @deleteBasketPB = findChild Qt::PushButton, 'deleteBasketPB'

    @deleteBasketPB.hide
    @quickPasteContent = Qt::Label.new do |l|
      l.setTextInteractionFlags Qt::TextSelectableByMouse|Qt::TextSelectableByKeyboard
      l.hide
    end
    @quickPasteL.setText QUICK_PASTE_LINK

    @itemGrid = BasketItemGrid.new
    @itemGrid.setSizePolicy(
        Qt::SizePolicy.new(
            Qt::SizePolicy.Maximum,
            Qt::SizePolicy.Maximum))

    @itemsArea.widget.layout.insertWidget 0, @quickPasteContent
    @itemsArea.widget.layout.insertWidget 0, @itemGrid

    connect @deleteBasketPB, SIGNAL('clicked()') do
      @itemGrid.deleteAll
      @deleteBasketPB.hide

      @items = []

      updateBasketInfo
      emit basketUpdated()
    end

    connect @closeBasketL, SIGNAL('linkActivated(const QString &)') do
      emit closeBasket()
    end

    connect @quickPasteL, SIGNAL('linkActivated(const QString &)') do
      if @itemGrid.isHidden
        @quickPasteContent.hide

        @quickPasteL.setText QUICK_PASTE_LINK

        m = @itemsArea.widget.layout.contentsMargins
        m.setTop 0
        @itemsArea.widget.layout.setContentsMargins m

        @itemGrid.show
        @deleteBasketPB.show unless @items.empty?

      else
        @itemGrid.hide
        @deleteBasketPB.hide

        @quickPasteL.setText SHOW_BASKET_LINK

        m = @itemsArea.widget.layout.contentsMargins
        m.setTop m.left
        @itemsArea.widget.layout.setContentsMargins m

        t = @items.reduce('') do |m,i|
          m+="#{i['sku']}, #{i['basketQuantity']}\n"
        end
        @quickPasteContent.setText t

        @quickPasteContent.show
      end
    end

    connect @itemGrid, SIGNAL('quantityChanged(int, int)') do |row, quant|
      @items[row]['basketQuantity'] = quant

      @itemGrid.updateProduct row, @items[row]

      updateBasketInfo
      emit basketUpdated()
    end
    connect @itemGrid, SIGNAL('deleted(int)') do |productIndex|
      @items.delete_at productIndex

      updateBasketInfo
      emit basketUpdated()
    end
  end

  def add(product_)
    if product_.kind_of? Qt::Object
      addItem product_.product

    elsif product_.kind_of? Array
      product_.each {|p| addItem p}

    else
      raise "wrong class of basket item!"
    end
  end

  def size
    @items.size
  end

  def total
    @items.reduce(0) {|m, i| m+=i.price*i.minQuant*i['basketQuantity']}
  end

  def totalStr
    "%0.2f" % total
  end

  private
  def updateBasketInfo
    @itemsL.text = "Items: #{size}"
    @totalL.text = "Total: #{totalStr}"

    size == 0 ? @deleteBasketPB.hide : @deleteBasketPB.show
  end

  def addItem(item)
    if itemIndex =
        (@items.find_index {|p| p['sku'] == item['sku']})

      @items[itemIndex]['basketQuantity'] += 1
      @itemGrid.updateProduct(
          itemIndex,
          @items[itemIndex])

    else
      item['basketQuantity'] = 1 unless item.has_key? 'basketQuantity'
      @items << item

      @itemGrid.addItem item
    end

    updateBasketInfo
    emit basketUpdated()
  end
end
