# ==========================
# Minesweeper - Ruby + Gosu
# ==========================
# This is a single-file implementation of Minesweeper.
# The following sections define the game components:
#
# 1. Layout Constants
# 2. Configuration & Asset Management
# 3. UI Components (Panels, Watcher)
# 4. Grid Logic (Tile, Board, Click Handling)
# 5. Game Window (Minesweeper Class)
#
# Author: Elliot Barlas
# ==========================

require 'optparse'
require 'gosu'

module Layout
  DIGIT_PANEL_WIDTH = 65
  DIGIT_PANEL_HEIGHT = 37
  DIGIT_PANEL_TOP = 21
  DIGIT_PANEL_MARGIN = 2
  DIGIT_WIDTH = 19
  DIGIT_HEIGHT = 33

  GRID_LEFT = 15
  GRID_TOP = 81
  GRID_SIDE = 20

  FACE_TOP = 18
  FACE_SIDE = 42
end

Config = Struct.new(:size, :width, :height, :face_left, :flags_left, :rows, :cols, :mines, keyword_init: true) do
  def self.create(mode)
    new(case mode
        when :intermediate
          { size: 'medium', width: 350, height: 416, face_left: 154, flags_left: 20, rows: 16, cols: 16, mines: 40 }
        when :expert
          { size: 'large', width: 630, height: 416, face_left: 273, flags_left: 20, rows: 16, cols: 30, mines: 99 }
        else
          { size: 'small', width: 210, height: 276, face_left: 84, flags_left: 16, rows: 9, cols: 9, mines: 10 }
        end)
  end
end

class Assets
  def initialize
    @images = Dir.glob("images/*.png").to_h do |f|
      [File.basename(f, '.png'), Gosu::Image.new(f)]
    end
  end

  def image(name)
    @images[name]
  end

  def digit(n)
    image "digit_#{n}"
  end

  def background(size)
    image "background_#{size}"
  end

  def face(state)
    image "face_#{state}"
  end
end

class Component
  include Layout

  def on_left_click(x, y) end

  def on_right_click(x, y) end
end

class Background < Component
  def initialize(assets, config)
    @assets = assets
    @size = config.size
  end

  def draw
    @assets.background(@size).draw(0, 0)
  end
end

class Watcher < Component
  def initialize(assets, config, timer, flag_panel)
    @assets = assets
    @left = config.face_left
    @timer = timer
    @flag_panel = flag_panel
    @state = :init
  end

  def grid=(grid)
    @grid = grid
  end

  def on_left_click(x, y)
    return unless x.between?(@left, @left + FACE_SIDE) && y.between?(FACE_TOP, FACE_TOP + FACE_SIDE)
    @state = :init
    @timer.reset
    @grid.reset
    @flag_panel.reset
  end

  def draw
    suffix = case @state
             when :lost then 'lose'
             when :won then 'win'
             else 'playing'
             end
    @assets.face(suffix).draw(@left, FACE_TOP)
  end

  def start
    @state = :playing
    @timer.start
  end

  def lost
    @state = :lost
    @timer.stop
  end

  def won
    @state = :won
    @timer.stop
  end

  def playing?
    [:init, :playing].include? @state
  end
end

class DigitPanel
  include Layout

  def initialize(assets, left)
    @assets = assets
    @left = left
  end

  def draw(value)
    @assets.image('digit_panel').draw(@left, DIGIT_PANEL_TOP)
    left = @left + DIGIT_PANEL_WIDTH - DIGIT_PANEL_MARGIN - DIGIT_WIDTH
    3.times do
      value, rem = value.divmod 10
      @assets.digit(rem).draw(left, DIGIT_PANEL_TOP + DIGIT_PANEL_MARGIN)
      left -= DIGIT_WIDTH + DIGIT_PANEL_MARGIN
    end
  end
end

class FlagPanel < Component
  def initialize(assets, config)
    @orig_flags = config.mines
    @flags = config.mines
    @panel = DigitPanel.new assets, config.flags_left
  end

  def reset
    @flags = @orig_flags
  end

  def flags=(flags)
    @flags = flags
  end

  def draw
    @panel.draw @flags
  end
end

class TimerPanel < Component
  def initialize(assets, config)
    @panel = DigitPanel.new assets, config.width - config.flags_left - DigitPanel::DIGIT_PANEL_WIDTH
  end

  private def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def start
    @started_at = now
  end

  def stop
    @stopped_at = now
  end

  def reset
    @started_at = nil
    @stopped_at = nil
  end

  private def elapsed
    return 0 unless @started_at
    Integer((@stopped_at || now) - @started_at)
  end

  def draw
    @panel.draw elapsed
  end
end

Tile = Struct.new(:row, :col, :mine, :neighbor_mines, :revealed, :flagged, keyword_init: true)

class Grid < Component
  def initialize(config, assets, watcher, flag_panel)
    @rows = config.rows
    @cols = config.cols
    @mines = config.mines
    @assets = assets
    @watcher = watcher
    @flag_panel = flag_panel
    reset
  end

  def self.place_mines(rows, cols, count)
    (0...rows).to_a.product((0...cols).to_a).sample(count).to_set
  end

  def reset
    mines = Grid.place_mines(@rows, @cols, @mines)
    @grid = Array.new(@rows) do |r|
      Array.new(@cols) do |c|
        Tile.new(
          row: r,
          col: c,
          mine: mines.include?([r, c]),
          neighbor_mines: neighbor_mines(mines, r, c),
          revealed: false,
          flagged: false)
      end
    end
  end

  private def neighbors(row, col)
    return enum_for(:neighbors, row, col) unless block_given?
    (row - 1).upto(row + 1) do |r|
      (col - 1).upto(col + 1) do |c|
        yield r, c if (r != row || c != col) && valid_row_col?(r, c)
      end
    end
  end

  private def row_cols
    return to_enum(:row_cols) unless block_given?
    @rows.times do |r|
      @cols.times { |c| yield r, c }
    end
  end

  private def neighbor_mines(mines, row, col)
    neighbors(row, col)
      .count { |r, c| mines.include?([r, c]) }
  end

  private def neighbor_flags(row, col)
    neighbors(row, col)
      .map { |r, c| tile_at_row_col(r, c) }
      .count { |t| t.flagged }
  end

  private def valid_row_col?(row, col)
    row.between?(0, @rows - 1) && col.between?(0, @cols - 1)
  end

  private def tile_at_row_col(row, col)
    valid_row_col?(row, col) ? @grid[row][col] : nil
  end

  private def tile_at_xy(x, y)
    tile_at_row_col (y - GRID_TOP) / GRID_SIDE, (x - GRID_LEFT) / GRID_SIDE
  end

  private def any_revealed?
    row_cols.map { |r, c| @grid[r][c] }.any? { |tile| tile.revealed }
  end

  private def count_revealed
    row_cols.map { |r, c| @grid[r][c] }.count { |tile| tile.revealed }
  end

  private def count_flags
    row_cols.count { |r, c| @grid[r][c].flagged }
  end

  private def reveal_neighbors(row, col)
    neighbors(row, col).each { |r, c| reveal(tile_at_row_col(r, c)) }
  end

  private def reveal(tile)
    return unless @watcher.playing?
    return if tile.revealed || tile.flagged
    unless any_revealed?
      @watcher.start
    end
    if tile.mine
      @watcher.lost
    end
    tile.revealed = true
    if tile.neighbor_mines.zero?
      reveal_neighbors(tile.row, tile.col)
    end
  end

  private def flag(tile)
    return unless @watcher.playing?
    return if tile.revealed
    if tile.flagged
      tile.flagged = false
    elsif count_flags < @mines
      tile.flagged = true
    end
    @flag_panel.flags = @mines - count_flags
  end

  def on_left_click(x, y)
    tile = tile_at_xy(x, y)
    return unless tile
    if tile.revealed && neighbor_flags(tile.row, tile.col) == tile.neighbor_mines
      reveal_neighbors(tile.row, tile.col)
    else
      reveal(tile)
    end
    if count_revealed == @rows * @cols - @mines
      @watcher.won
    end
  end

  def on_right_click(x, y)
    flag tile_at_xy(x, y)
  end

  def draw
    row_cols.each do |r, c|
      tile = @grid[r][c]
      name = case
             when tile.flagged then 'tile_flag'
             when !tile.revealed then 'tile'
             when tile.mine then 'tile_mine'
             else "tile_#{tile.neighbor_mines}"
             end
      @assets.image(name).draw(GRID_LEFT + GRID_SIDE * c, GRID_TOP + GRID_SIDE * r)
    end
  end
end

class Minesweeper < Gosu::Window
  def initialize(width, height, layers)
    super width, height
    self.caption = "Minesweeper"
    @layers = layers
  end

  def button_up(id)
    mx, my = Integer(mouse_x), Integer(mouse_y)
    if id == Gosu::MS_LEFT
      @layers.each { |layer| layer.on_left_click(mx, my) }
    end
    if id == Gosu::MS_RIGHT
      @layers.each { |layer| layer.on_right_click(mx, my) }
    end
  end

  def draw
    @layers.each(&:draw)
  end
end

def parse_options
  mode = :intermediate
  OptionParser.new do |opts|
    opts.banner = "Usage: minesweeper [options]"
    opts.on("-b", "--beginner", "Start game in Beginner mode") { mode = :beginner }
    opts.on("-i", "--intermediate", "Start game in Intermediate mode") { mode = :intermediate }
    opts.on("-e", "--expert", "Start game in Expert mode") { mode = :expert }
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!
  mode
end

def main
  mode = parse_options
  assets = Assets.new
  config = Config.create mode
  background = Background.new assets, config
  timer = TimerPanel.new assets, config
  flags = FlagPanel.new assets, config
  watcher = Watcher.new assets, config, timer, flags
  grid = Grid.new config, assets, watcher, flags
  watcher.grid = grid
  layers = [background, grid, flags, timer, watcher]
  Minesweeper.new(config.width, config.height, layers).show
end

main