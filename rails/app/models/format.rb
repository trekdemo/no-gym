# Text formats shared by the list, the editor and the done screen (spec 13.6).
module Format
  module_function

  # "0:05", "4:00", "1:02:03". Rounds up, like the countdown.
  def clock(seconds)
    total = [ seconds.to_f.ceil, 0 ].max
    hours, rest = total.divmod(3600)
    minutes, secs = rest.divmod(60)
    hours.positive? ? format("%d:%02d:%02d", hours, minutes, secs) : format("%d:%02d", minutes, secs)
  end

  # "20 s", "5.5 s", "1 min", "1 min 30 s".
  def duration(seconds)
    seconds = seconds.to_f
    if seconds < 60
      return seconds.round == seconds ? "#{seconds.to_i} s" : format("%.1f s", seconds)
    end
    minutes, rest = seconds.round.divmod(60)
    rest.zero? ? "#{minutes} min" : "#{minutes} min #{rest} s"
  end

  def plural(count, noun)
    "#{count} #{noun}#{'s' unless count == 1}"
  end

  # "8 rounds · 4:00"
  def summary(sequence)
    "#{plural(sequence.rounds.to_i, 'round')} · #{clock(sequence.total_seconds)}"
  end
end
