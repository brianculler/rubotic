require 'shellwords'

class Rubotic::PluginManager
  attr_reader :plugins

  def initialize(bot)
    @plugins = Rubotic::Plugin.registered.map do |p|
      p.send(:new, bot) rescue nil
    end.compact

    @plugins.each do |p|
      puts "Loaded #{p.class.name}: #{p.class.description}"
    end
  end

  def dispatch(event)
    cmd, *args = Shellwords.shellwords(event.args.last)

    if (p = @plugins.find{ |plug| plug.accepts?(cmd) })
      p.invoke!(event, cmd, *args)
    end
  rescue => err
    puts "A plugin misbehaved: #{err.class}: #{err.message}"

    (err.backtrace || []).each do |line|
      puts "  #{line}"
    end

  end
end
