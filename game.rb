class Game
  attr_accessor :players, :deck, :community_cards, :pot, :call_amount, :bb, :hand_number

  COMMANDS = ['check','call','bet','raise','allin','fold']

  def initialize
    @deck = Deck.new
    @pot = 0
    @community_cards = []
    @bb = 100
    @call_amount = 0
    @hand_number = 0
  end

  def to_s
    "#{@community_cards.map(&:to_s).join(' ')} pot #{@pot} bb #{@bb}"
  end

  def start
    @players = [Player.new("player1"), Player.new("player2")]

    loop do
      @hand_number += 1
      puts "\n\nhand##{@hand_number}"
      start_hand
      start_round
      next if finish_hand_if_finished
      3.times do
        @community_cards << @deck.deal
      end
      start_round
      next if finish_hand_if_finished
      @community_cards << @deck.deal
      start_round
      next if finish_hand_if_finished
      @community_cards << @deck.deal
      start_round
      next if finish_hand_if_finished
      showdown
    end
  end

  def start_hand
    @pot = 0
    @community_cards = []
    @call_amount = 0

    @players.each do |player|
      player.start_hand
    end

    2.times do
      @players.each do |player|
        player.hole_cards.cards << @deck.deal
      end
    end

    puts @players[0]
    puts @players[1]
  end

  def start_round
    puts
    puts self
    @players.each{ |player| player.start_round }
    loop do
      @players.each do |player|
        #print "#{player.name} chip #{player.chip}:"
        print "#{player}:"
        command = STDIN.gets.strip
        parse_and_exec_command(command, player)
        player.action_done = true
        puts self
        if round_finished? || hand_finished?
          return
        else
          puts "bets:#{@players.map{ |player| "#{player.name}:#{player.current_bet}"}.join(", ")}"
        end
      end
    end
  end

  def round_finished?
    @players.all?{ |player| player.action_done && player.current_bet == @players[0].current_bet }
  end

  def hand_finished?
    @players.count{ |player| !player.folded } == 1
  end

  def finish_hand
    winner = @players.find{ |player| !player.folded }
    winner.chip += @pot
    puts "#{winner.name} won #{@pot}"
  end

  def finish_hand_if_finished
    if hand_finished?
      finish_hand
      return true
    end
    false
  end

  def showdown
  end

  def parse_and_exec_command(command_str, player)
    tokens = command_str.split(' ')
    unless COMMANDS.include?(tokens[0])
      puts "invalid command1"
      return false
    end
    command = tokens[0]
    if command == 'bet' || command == 'raise'
      unless tokens.size <= 2
        puts "invalid command2"
        return false
      end
      argument = tokens[1].to_i
      self.send(command, player, argument)
    else
      self.send(command, player)
    end
    true
  end

  def check(player)
    #puts "command: check"
    return false unless @call_amount == 0
    true
  end

  def call(player)
    #puts "command: call"
    amount = @call_amount - player.current_bet
    player.chip -= amount
    @pot += amount
    player.current_bet = @call_amount
    true
  end

  def bet(player,amount)
    #puts "command: bet"
    player.chip -= amount
    @pot += amount
    @call_amount = amount
    player.current_bet = amount
    true
  end

  def raise(player,amount)
    #puts "command: raise"
    player.chip -= amount
    @pot += amount
    @call_amount += amount
    player.current_bet = amount
    true
  end

  def allin(player)
    true
  end

  def fold(player)
    player.folded = true
    true
  end

end

class Deck
  attr_accessor :cards

  SUITES = ['s','h','d','c']

  def initialize
    @cards = SUITES.map{ |suite| 1.upto(13).map{ |n| Card.new(n,suite) } }.flatten.shuffle
  end

  def deal
    @cards.pop
  end
end

class Card
  attr_accessor :number, :suite
  def initialize(number,suite)
    @number = number
    @suite = suite
  end

  def number_label
    case @number
    when 1
      "A"
    when 11
      "J"
    when 12
      "Q"
    when 13
      "K"
    else
      @number.to_s
    end
  end

  def to_s
    "#{number_label}#{@suite}"
  end
end

class Player
  attr_accessor :name, :chip, :hole_cards, :current_bet, :action_done, :folded

  def initialize(name)
    @chip = 5000
    @hole_cards = HoleCards.new
    @name = name
    @current_bet = 0
    @action_done = true
    @folded = false
  end

  def to_s
    "#{@name} #{@hole_cards} chip #{@chip}, bet #{@current_bet}"
  end

  def start_hand
    @hole_cards = HoleCards.new
    @current_bet = 0
    @action_done = false
    @folded = false
  end

  def start_round
    @current_bet = 0
    @action_done = false
  end
end

class HoleCards
  attr_accessor :cards

  def initialize
    @cards = []
  end

  def to_s
    cards.map(&:to_s).join
  end
end

class Hand
  attr_accessor :cards

  # straight flash 8
  # 4 of a kind    7
  # full house     6
  # flash          5
  # straight       4
  # 3 of a kind    3
  # 2 pairs        2
  # 1 pair         1
  # no hand        0
  HAND_STRENGTH = [straight_flash: 8,
                   four_of_a_kind: 7,
                   full_house:     6,
                   flash:          5,
                   straight:       4,
                   three_of_a_kind:3,
                   two_pairs:      2,
                   one_pair:       1,
                   no_hand:        0]

  def initialize(cards)
    @cards = cards
  end

  def to_s
    @cards.map(&:to_s).join
  end

  def strength
    @cards.combination(5).each do |combi|
      return HAND_STRENGTH[:straight_flash] if is_straight_flash?(combi)
      return HAND_STRENGTH[:four_of_a_kind] if is_four_of_a_kind?(combi)
      return HAND_STRENGTH[:full_house] if is_full_house?(combi)
      return HAND_STRENGTH[:flash] if is_flash?(combi)
      return HAND_STRENGTH[:straight] if is_straight?(combi)
      return HAND_STRENGTH[:three_of_a_kind] if is_three_of_a_kind?(combi)
      return HAND_STRENGTH[:two_pairs] if is_two_pairs?(combi)
      return HAND_STRENGTH[:one_pair] if is_one_pair?(combi)
      return HAND_STRENGTH[:no_hand]
    end
  end

  def is_straight_flash?(cards)
     is_flash?(cards) && is_straight(cards)
  end

  def is_four_of_a_kind?(cards)
    @cards.group_by(&:number).map(&:size).max == 4
  end

  def is_full_house?(cards)
    is_three_of_a_kind?(cards) && is_one_pair?(cards)
  end

  def is_flash?(cards)
    @cards.all?{ |card| card.suit == @cards[0] }
  end

  def is_straight?(cards)
    cards.sort_by(&:number)
  end

  def is_three_of_a_kind?(cards)
    @cards.group_by(&:number).map(&:size).max == 3
  end

  def is_two_pairs?(cards)
  end

  def is_one_pair?(cards)
  end

end

game = Game.new
game.start
