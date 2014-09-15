Dir.chdir File.dirname(__FILE__)

require 'Qt'
require 'pp'

require_relative 'lib/main'
require_relative 'lib/farnell'
require_relative 'lib/filters'
require_relative 'lib/settings'
require_relative 'lib/searchCache'
require_relative 'lib/netlists'
require_relative 'lib/basket'

app = Qt::Application.new(ARGV)

class Components < Qt::MainWindow
  def initialize(parent=nil)
    super

    setWindowTitle 'Components'

    @products = Main.new
    @basket = Basket.new

    @stackedWidget = Qt::StackedWidget.new
    @stackedWidget.addWidget @products
    @stackedWidget.addWidget @basket
    @stackedWidget.setCurrentWidget @products

    setCentralWidget @stackedWidget

    @settings = SettingsDialog.new
    connect @settings, SIGNAL('farnellApiKeyChanged(const QString &)') do |apiKey|
      $farnell.apiKey = apiKey
    end
    @settings.load

    # Filters
    addDock(
        @filters = Filters.new,
        'Filters',
        'filters')

    connect(
        @filters, SIGNAL('filterActivated(QWidget *)'),
        @products, SLOT('filterActivated(QWidget *)'))
    connect(
        @filters, SIGNAL('filterDeactivated(QWidget *)'),
        @products, SLOT('filterDeactivated(QWidget *)'))
    connect(
        @products, SIGNAL('search(QString *)'),
        @filters, SLOT('refreshFilterList(QString *)'))

    # Search cache
    addDock(
        @searchCache = SearchCache.new,
        'Search cache',
        'searchCache')

    connect(
        @products, SIGNAL('supplierChanged(QObject *)'),
        @searchCache, SLOT('supplierChanged(QObject *)'))
    connect(
        @searchCache, SIGNAL('cacheSelected(const QString &)'),
        @products, SLOT('searchFor(const QString &)'))

    # Netlists
    addDock(
        @netlists = Netlists.new,
        'Netlists',
        'netlists')

    # Basket
    addDock(
        @basketInfo = BasketInfo.new(@basket),
        'Basket',
        'basket')

    connect(
        @products, SIGNAL('productRightClick(QObject *)'),
        @basket, SLOT('add(QObject *)'))
    connect @basketInfo, SIGNAL('showCompleteBasket()') do
      @stackedWidget.setCurrentWidget @basket
    end
    connect @basket, SIGNAL('closeBasket()') do
      @stackedWidget.setCurrentWidget @products
    end
    connect(
        @basket, SIGNAL('basketUpdated()'),
        @basketInfo, SLOT('basketUpdated()'))

    connect $qApp, SIGNAL('lastWindowClosed()') do gone end

    # Menu
    settingsA = menuBar.addAction '&Settings'

    connect settingsA, SIGNAL('triggered()') do settings end

    @products.refresh

    Settings.restoreMainWindowSettings self
  end

  def gone
    Settings.saveMainWindowSettings self
  end

  def settings
    @settings.save if @settings.exec == Qt::Dialog::Accepted
  end

  private
  def addDock(widget, title, objectName)
    dock = Qt::DockWidget.new title, self
    dock.setObjectName objectName
    dock.allowedAreas = Qt::AllDockWidgetAreas
    dock.widget = widget

    addDockWidget Qt::LeftDockWidgetArea, dock
    menuBar.addAction dock.toggleViewAction
  end
end

Components.new.show
app.exec

