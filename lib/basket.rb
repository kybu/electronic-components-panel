require_relative 'helpers'

require 'Qt'

class BasketInfo < Qt::Widget
  include WidgetHelpers

  slots 'add(QObject *)'
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

  def add(product)
    @basket.add product.product

    @itemsL.text = "Items: #{@basket.size}"
    @totalL.text = "Total: #{@basket.total}"
  end
end

class BasketItemGrid < Qt::Widget
  include WidgetHelpers

  def initialize(parent=nil)
    super

    @itemGrid = Qt::GridLayout.new(self) do |l|
      l.addWidget(
          Qt::Label.new('<b>Product</b>'),
          0, 0)
      l.addWidget(
          Qt::Label.new('<b>Quantity</b>'),
          0, 1)
      l.addWidget(
          Qt::Label.new('<b>Price</b>'),
          0, 2)
      l.addWidget(
          Qt::Label.new('<b>Total price</b>'),
          0, 3)

      l.setColumnStretch 0, 1
      l.setColumnStretch 1, 0
      l.setColumnStretch 2, 0
      l.setColumnStretch 3, 0
    end

    @quantities = []
  end

  def addItem(product)
    @itemGrid.addWidget(
        Qt::Label.new(product['displayName']),
        @itemGrid.rowCount, 0)

    # Quantity input
    layout = Qt::HBoxLayout.new
    layout.addStretch 1
    layout.addWidget Qt::Label.new(product.minQuant.to_s+"x")

    v = Qt::IntValidator.new
    v.setBottom 1

    le = Qt::LineEdit.new
    le.setValidator v
    le.setText product['basketQuantity'].to_s
    le.setFixedWidth 41
    layout.addWidget le

    @itemGrid.addLayout(
        layout,
        @itemGrid.rowCount-1, 1)

    @itemGrid.addWidget(
        Qt::Label.new(product.price.to_s),
        @itemGrid.rowCount-1, 2)

    @itemGrid.addWidget(
        (totalPrice = Qt::Label.new((product.price*product['basketQuantity']).to_s)),
        @itemGrid.rowCount-1, 3)

    @quantities << [le, totalPrice]
  end

  def updateProduct(row, product)
    @quantities[row][0].setText product['basketQuantity'].to_s
    @quantities[row][1].setText(
        (product['basketQuantity']*product.price).to_s)
  end
end

class Basket < Qt::Widget
  include WidgetHelpers

  signals 'closeBasket()'

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
  end

  def add(product)
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

    @itemsL.text = "Items: #{size}"
    @totalL.text = "Total: #{total}"
  end

  def size
    @items.size
  end

  def total
    @items.reduce(0) {|m, i| m+=i.price*i.minQuant*i['basketQuantity']}
  end
end
