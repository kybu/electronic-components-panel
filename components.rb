Dir.chdir File.dirname(__FILE__)

require 'Qt'
require 'pp'

require_relative 'lib/main'
require_relative 'lib/filters'
require_relative 'lib/settings'
require_relative 'lib/searchCache'
require_relative 'lib/netlists'

app = Qt::Application.new(ARGV)

class Components < Qt::MainWindow
  def initialize(parent=nil)
    super

    setWindowTitle 'Components'

    @products = Main.new
    setCentralWidget @products

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

    connect $qApp, SIGNAL('lastWindowClosed()') do gone end

    @products.refresh

    Settings.restoreMainWindowSettings self
  end

  def gone
    Settings.saveMainWindowSettings self
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

