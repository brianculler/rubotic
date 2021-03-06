require 'time'

class TriviaPlugin < Rubotic::Plugin
  describe "let's play trivia"

  command '!blacklist' do
    arguments 0..0
    describe 'blacklist a trivia question'

    run do |event|
      if current_question
        q = current_question[:question]
        a = current_question[:answer]
        blacklist_id(current_question[:id])
        clear_question
        respond_to(event, "OK, I won't ask #{q} again. The answer was #{a}.")
      elsif @last_id
        q = get_question(@last_id)[:question]
        blacklist_id(@last_id)
        @last_id = nil
        respond_to(event, "OK, I won't ask #{q} again.")
      else
        respond_to(event, "no question to blacklist.")
      end
    end
  end

  
  command '!vowels' do
    describe 'give a hint'
    arguments 0..0

    run do |event|
      if !current_question
        respond_to(event, "Can't give hints because there's no current question. !trivia for a new question", private: false)
      else
        respond_to(event, current_question[:answer].gsub(/[^AaEeIiOoUu\s]/, '-'), private: false)
      end
    end
  end

  command '!trivia' do
    describe 'ask a trivia question'
    arguments 0..0

    run do |event|
      if !event.args.first.start_with?('#')
        respond_to(event, "-1 for trying to cheat you dick.")
        point_for(event.from.nick, -1)
        return
      end

      if !current_question
        new_question
        respond_to(event, "#{current_question[:question]}", private: false)
      else
        respond_to(event, "Current question (!giveup to skip): #{current_question[:question]}", private: false)
      end
    end
  end

  command '!score' do
    describe 'see trivia scores for a user'
    usage '<user>'
    arguments 1..1

    run do |event, who|
      row = @bot.db[:trivia_scores].where(nick: who).first
      pts = row ? row[:score] : 0
      respond_to(event, "#{who}: #{pts} points.")
    end
  end

  command '!giveup' do
    describe 'shameful'
    arguments 0..0

    run do |event|
      if current_question && timed_out?
        respond_to(event, "The answer was: #{current_question[:answer]}.  Use !trivia for a new question.", private: false)
        clear_question
      elsif current_question
        respond_to(event, "You can give up in #{asked_at + 30 - Time.now} seconds")
      end
    end
  end

  command '!answer' do
    describe 'answer a trivia question'
    arguments 1..100

    run do |event, *args|
      if current_question
        answer = args.join(' ').downcase
        if right_answer(answer)
          clear_question
          point_for(event.from.nick)
          respond_to(event, "#{event.from.nick} is right! Huzzah! Use !trivia for a new question.", private: false)
        end
      else
        respond_to(event, "No active question! Use !trivia to ask one.")
      end

    end
  end

  private

  def trivia_db
    @trivia_db || SQLite3::Database.new(
      File.join(
        Rubotic.root, 'config', 'plugins', 'trivia.db'
      )
    )
  end

  def right_answer(answer)
    q = current_question
    q[:answer].downcase == answer
  end

  attr_reader :current_question
  attr_reader :asked_at

  def point_for(who, amount=1)
    row = @bot.db[:trivia_scores].where(nick: who).first
    if row
      @bot.db[:trivia_scores].where(nick: who).update(score: row[:score] + amount)
    else
      @bot.db[:trivia_scores].insert(nick: who, score: amount)
    end
  end

  def clear_question
    @last_id          = @current_id
    @current_id       = nil
    @current_question = nil
    @asked_at         = nil
  end

  def get_question(id)
    q = trivia_db.execute("SELECT id, question, answer FROM questions WHERE id = ?", id).first

    {
      id:       q[0],
      question: q[1],
      answer:   q[2]
    }
  end

  def blacklist_id(id)
    trivia_db.execute("DELETE FROM questions WHERE id = ?", id)
  end

  def timed_out?
    asked_at && (asked_at + 30) < Time.now
  end

  def new_question
    q = trivia_db.execute("SELECT id, question, answer FROM questions ORDER BY RANDOM() LIMIT 1").first
    @current_question = {
      id:       q[0],
      question: q[1],
      answer:   q[2]
    }
    @current_id = @current_question[:id]
    @asked_at = Time.now
  end

  def can_get_new?
    current_question.nil? || timed_out?
  end

  def initialize(bot)
    @current_question = nil
    @current_id       = nil
    @asked_at         = nil

    @bot = bot
    @bot.db.create_table?(:trivia_scores) do
      primary_key :id
      String      :nick,  unique: true, null: false
      Integer     :score, null: false,  default: 0
    end
  end

end
