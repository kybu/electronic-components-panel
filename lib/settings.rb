require 'Qt'

class Settings
  @settings = Qt::Settings.new(
      Qt::Settings.UserScope,
      Qt::Settings.NativeFormat,
      'kybu',
      'Components')

  MAINWINDOW_STATE_REG = 'mainWindowState'
  MAINWINDOW_GEOMETRY_REG = 'mainWindowGeometry'

  def self.restoreMainWindowSettings(mWindow)
    mainWindowState = @settings.value(MAINWINDOW_STATE_REG).toByteArray
    mainWindowGeometry = @settings.value(MAINWINDOW_GEOMETRY_REG).toByteArray

    mWindow.restoreState mainWindowState
    mWindow.restoreGeometry mainWindowGeometry
  end

  def self.saveMainWindowSettings(mWindow)
    @settings.setValue(
        MAINWINDOW_STATE_REG, Qt::Variant.fromValue(mWindow.saveState))
    @settings.setValue(
        MAINWINDOW_GEOMETRY_REG, Qt::Variant.fromValue(mWindow.saveGeometry))

    @settings.sync
  end
end