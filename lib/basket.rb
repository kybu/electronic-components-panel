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

  signals 'quantityChanged(int, int)', # productIndex, quantity
          'deleted(int)' # productIndex

  Item = Struct.new(
      :productIndex, :displayName,
      :quantLayoutLE, :quantLayoutL, :quantLayout,
      :price, :totalPrice, :delete)

  def initialize(parent=nil)
    super

    @itemGrid = Qt::GridLayout.new(self) do |l|
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

    connect item.delete, SIGNAL('clicked()') do
      @toDelete << item

      item.displayName.hide
      item.price.hide
      item.totalPrice.hide
      item.delete.hide

      item.quantLayoutLE.hide
      item.quantLayoutL.hide

      @items.delete item

      emit deleted(item.productIndex)
    end

    @itemGrid.addWidget(
        item.delete,
        @itemGrid.rowCount-1, 4)

    @items << item
  end

  def updateProduct(productIndex, product)
    @items[productIndex].quantLE.setText product['basketQuantity'].to_s
    @items[productIndex].totalPrice.setText product.totalPriceStr
  end
end

class Basket < Qt::Widget
  include WidgetHelpers

  signals 'closeBasket()', 'basketUpdated()'
  slots   'add(QObject *)'

  def initialize
    super

    @items = []

    loadUi 'basket'

    @totalL = findChild Qt::Label, 'totalL'
    @itemsL = findChild Qt::Label, 'itemsL'
    @closeBasketL = findChild Qt::Label, 'closeBasketL'
    @itemsArea = findChild Qt::ScrollArea, 'itemsArea'

    @itemGrid = BasketItemGrid.new
    @itemGrid.setSizePolicy(
        Qt::SizePolicy.new(
            Qt::SizePolicy.Maximum,
            Qt::SizePolicy.Maximum))

    @itemsArea.widget.layout.insertWidget 0, @itemGrid

    connect @closeBasketL, SIGNAL('linkActivated(const QString &)') do
      emit closeBasket()
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
    product = product_.product

    if productIndex =
       (@items.find_index {|p| p['sku'] == product['sku']})

      @items[productIndex]['basketQuantity'] += 1
      @itemGrid.updateProduct(
          productIndex,
          @items[productIndex])

    else
      product['basketQuantity'] = 1
      @items << product

      @itemGrid.addItem product
    end

    updateBasketInfo

    emit basketUpdated()
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
  end
end
