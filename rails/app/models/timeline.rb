# A sequence laid out in time (spec 6): the prep first, then every interval of
# round 1, then of round 2, and so on. Times are seconds from the run's start.
class Timeline
  Step = Data.define(:round, :index_in_round, :interval, :start, :end) do
    def duration = self.end - start
  end

  attr_reader :prep_duration, :steps, :rounds, :steps_per_round

  def initialize(template, rounds, prep_seconds)
    @prep_duration = [ prep_seconds.to_f, 0.0 ].max
    @rounds = [ rounds.to_i, 0 ].max
    @steps = []
    @steps_per_round = 0
    time = @prep_duration
    @rounds.times do |round|
      intervals = template.intervals(round)
      @steps_per_round = [ @steps_per_round, intervals.size ].max
      intervals.each_with_index do |interval, index|
        length = [ interval.seconds.to_f, 0.0 ].max
        @steps << Step.new(round: round + 1, index_in_round: index, interval:, start: time, end: time + length)
        time += length
      end
    end
  end

  # The end of the last step, or the prep length if there are no steps.
  def duration = steps.empty? ? prep_duration : steps.last.end

  # Everything but the prep: the "total time" shown in lists and the editor.
  def work_duration = duration - prep_duration

  def last_in_round?(index)
    index == steps.size - 1 || steps[index + 1].round != steps[index].round
  end
end
