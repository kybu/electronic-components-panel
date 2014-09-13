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
    @basketItemsL = findChild Qt::Label, 'basketItemsL'

    @basketItemsL.setText ''

    connect @closeBasketL, SIGNAL('linkActivated(const QString &)') do
      emit closeBasket()
    end
  end

  def add(product)
    @items << product

    @itemsL.text = "Items: #{size}"
    @totalL.text = "Total: #{total}"

    text = @basketItemsL.text
    @basketItemsL.setText(text+"#{product['displayName']}\n")
  end

  def size
    @items.size
  end

  def total
    @items.reduce(0) {|m, i| m+=i.price*i.minQuant}
  end
end
