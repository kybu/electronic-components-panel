class ProductsModel < Qt::AbstractTableModel
  def initialize(data, parent=nil)
    super(parent)
    @data = data
  end

  def rowCount(parent)
    data.size
  end

  def columnCount(parent)
    3
  end

  def data(index, role)
    if !index.valid?
      return Qt::Variant.new
    elsif role == Qt::ToolTipRole
      return Qt::Variant.new
    end

    return Qt::Variant.new(data[index.row])
  end
end
