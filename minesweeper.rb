require "yaml"
require "json"

class Minesweeper
  attr_accessor :minefield, :start_time, :elapsed_time

  def initialize(board_size=9, num_mines=10)
    @minefield = Minefield.new(board_size, num_mines)
    @start_time = Time.now
    @elapsed_time = 0
  end


  def get_move
    moves = []
    # puts "---------->"
    while moves.length < 2
      print "Please place your move. e.g. A,0 to reveal or F,A,0 to flag: "
      moves = STDIN.gets.upcase.chomp.split ","
    end
    if moves == []
      return {:action => "N", :position => [-1,-1]}
    end
    target = [moves[-1].to_i, moves[-2]]
    target[-1] = ("A".."Z").to_a.index(target[-1].upcase)
    if moves.length == 3
      return {:action => "F", :position => target}
    else
      return {:action => "N", :position => target}
    end
  end

  def save_game
    serialized_game = self.to_yaml
    File.open("minesweeper.yaml","w+") do |f|
      f.puts serialized_game
    end
  end

  def self.load_game(file_name="minesweeper.yaml")
    minesweeper = YAML::load(File.read(file_name))
    minesweeper.start_time = Time.now - minesweeper.elapsed_time

    puts minesweeper.elapsed_time
    puts minesweeper.start_time
    puts "----------"
    minesweeper.run
    ARGV.clear
  end

  def run
    end_state = false
    until end_state
      self.elapsed_time = (Time.now - start_time).round
      save_game()
      minefield.show(nil, self.elapsed_time)
      move_hash = get_move()
      minefield.process_move(move_hash)
      puts minefield.end_game?
      end_state = minefield.end_game?[0]
      winlose = minefield.end_game?[1]
    end
    puts winlose.to_s
    self.elapsed_time = (Time.now - start_time).round
    minefield.show(minefield.board_ref, self.elapsed_time)

    if winlose == :lose
      puts "BOOM!"
      # show(@board_mask, mine_swee)
      puts_bomb
    end
    puts "\n\n"
    puts "Play again?"

    if gets.chomp == "y"
      self.send :initialize
      run
    else
      puts "Goodbye"
      exit
    end
  end

  def puts_bomb
    b = <<-EOF
            ,--.!,
         __/   -*-
       ,d08b.  '|`
       0088MM
       `9MMP'
    EOF
    b.each_line{|l| print "\t"+l}#.rjust(minefield.line_length)}
  end

end

class Minefield
  attr_accessor :board_mask, :board_ref, :bomb_counter, :bombs_total, :line_length

  def initialize(board_size, num_mines)

    self.bomb_counter = num_mines
    self.bombs_total = num_mines
    build_board(board_size, num_mines)
    @line_length = 0

  end

  def show(board, time_diff = 0)
    board ||= @board_mask

    self.line_length = "#{@board_mask.length}| #{board_mask[0].join(" ")} |".length
    line = "\t"+("-"*self.line_length)
    system('clear')
    puts line
    puts "\tTime Elapsed: #{time_diff} sec".rjust(line_length)
    puts line
    puts "\tBombs Remaining: #{@bomb_counter}".rjust(line_length)
    puts line
    # print "   "
    header = ("A".."Z").to_a.take(board[0].length).join(" ")+" |"
#    (board[0].length-1).times{|x| header += "#{("A".."Z").to_a[x]}"}

    puts "\t"+header.rjust(line_length) #+" |".rjust(line_length)
    #(board[0].length-1).times{|x| print "#{x} "}
    puts line
    board.each_with_index { |row, rindex| puts "\t#{rindex}| #{row.join(" ")} |".rjust(line_length) }
    puts line+"\n\n\n\n"
  end

  def get_possible_positions
    possible_position_list = []
    board_ref.length.times do |row|
      board_ref.length.times do |col|
        possible_position_list << [row,col]
      end
    end
    possible_position_list
  end

  def place_bombs()
    # place random bombs
    possible_positions = get_possible_positions
    puts self.bombs_total
    self.bombs_total.times do
      new_pos = possible_positions.shuffle.pop
      self.board_ref[new_pos[0]][new_pos[1]] = "B"
    end

  end

  def find_fringe_squares()
    #updating ref board with numbered squares
    #determine and calculate fringe squares
    possible_positions = get_possible_positions
    possible_positions.each do |position|
      next if board_ref[position[0]][position[1]] == "B"
      neighbors = get_neighbors(position)
      bomb_count = neighbors.select do |neigh_pos|
        board_ref[neigh_pos[0]][neigh_pos[1]] == "B"
      end.length
      # puts bomb_count
      board_ref[position[0]][position[1]] = bomb_count == 0 ? " " : bomb_count
    end
  end

  #REFACTOR
  def build_board(board_size, num_bombs)
    self.board_mask = board_size.times.map { board_size.times.map {"*"} }
    self.board_ref = board_size.times.map { board_size.times.map {"*"} }
    place_bombs
    find_fringe_squares
    # show(board_mask)
    show(board_ref)
  end

  def get_neighbors(position)
    neighbors = []
    (-1..1).each do |r_offset|
      (-1..1).each do |c_offset|
        new_pos = [position[0]+r_offset, position[1]+c_offset]
        next if new_pos == position
        # puts "#{new_pos.join', '}, #{is_valid?(new_pos)}"
        neighbors << new_pos if is_valid?(new_pos)
      end
    end
    # p neighbors
    neighbors
  end

  def is_valid?(position)
    return position.all? {|coord| (0...board_ref.length) === coord} #board_mask[position[0]][position[1]].nil?
    true
  end

  def is_flagged?(position)
    return true if board_mask[position[0]][position[1]] == "F"
    false
  end

  def is_revealed?(position)
    return false if board_mask[position[0]][position[1]] == "*"
    return false if board_mask[position[0]][position[1]] == "F"
    true
  end

  def verify_move(action, position)
    if !is_valid?(position)
      puts "INCORRECT POSITION"
      false
    elsif is_revealed?(position)
      puts "Pick a square that is not revealed"
      false
    elsif is_flagged?(position) && (action != "F")
      puts "Cannot reveal flagged square. To unflag input 'F,#{position.join(",")}'"
      false
    else
      true
    end
  end

  def process_move(move_hash)
    update(move_hash[:action], move_hash[:position]) if verify_move(move_hash[:action], move_hash[:position])
  end

  def update(action, position)
    mask_value = self.board_mask[position[0]][position[1]]
    ref_value = self.board_ref[position[0]][position[1]]

    if action == "F"
      puts "IS A FLAG? #{self.board_mask[position[0]][position[1]]}"
      if mask_value == "*"
        self.board_mask[position[0]][position[1]] = "F"
        self.bomb_counter -= 1
      elsif mask_value == "F"
        self.board_mask[position[0]][position[1]] = "*"
        self.bomb_counter += 1
      end

    elsif ref_value == "B"
      self.board_mask = board_ref
      self.board_mask[position[0]][position[1]] = "!"

    elsif ref_value.is_a?(Fixnum)
      self.board_mask[position[0]][position[1]] = ref_value
    elsif ref_value == " "
      self.board_mask[position[0]][position[1]] = ref_value
      neighbors = get_neighbors(position)
      neighbors.each { |neigh| update("N", neigh) if mask_value == "*"}
    end
  end

  def end_game?

    if board_mask.any? { |row| row.include?("!") }

      return [true, :lose]
    else
      counter = 0
      board_mask.each do |row|
        counter += row.count("*")
        counter += row.count("F")
      end
      if counter == self.bombs_total
        puts "YOU WIN!"
        show(@board_ref)
        return [true, :win]
      end
    end

    [false, :none]
  end

end

#minesweeper.build_board
#Minesweeper.load_game('minesweeper.yaml')


if ARGV[0].nil?
  minesweeper = Minesweeper.new(9,12)
  minesweeper.run
else
  Minesweeper.load_game(ARGV[0])
  STDIN
end
