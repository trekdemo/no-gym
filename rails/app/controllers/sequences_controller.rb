class SequencesController < ApplicationController
  before_action :set_sequence, only: %i[edit update destroy run move]

  def index
    @editing = params[:editing].present?
    @sequences = Sequence.ordered.to_a
  rescue ActiveRecord::ActiveRecordError => error
    @sequences = []
    @error = "Couldn't read your sequences: #{error.message}"
  end

  # Without a kind, shows the template picker; with one, the editor with that kind's starter.
  def new
    kind = params[:kind]
    return render(:picker) unless SequenceTemplate::KINDS.include?(kind)

    @sequence = Sequence.starter(kind)
  end

  def create
    kind = params.dig(:sequence, :kind)
    raise ActionController::BadRequest, "unknown kind" unless SequenceTemplate::KINDS.include?(kind)

    @sequence = Sequence.new(kind:)
    @sequence.assign_attributes(sequence_params(kind))
    if @sequence.save
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sequence.update(sequence_params(@sequence.kind))
      redirect_to root_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sequence.destroy!
    redirect_to root_path(editing: params[:editing].presence), status: :see_other
  end

  def move
    @sequence.move(params[:direction] == "up" ? -1 : 1)
    redirect_to root_path(editing: 1), status: :see_other
  end

  def run
  end

  private

  def set_sequence
    @sequence = Sequence.find(params[:id])
  end

  # Settings and sounds are free-form JSON documents, so they're cleaned by
  # SequenceTemplate.normalize and SoundSettings.normalize, which keep only known fields.
  def sequence_params(kind)
    raw = params.require(:sequence)
    raw.permit(:title, :notes, :rounds, :prep_seconds).to_h.merge(
      settings: SequenceTemplate.normalize(kind, raw[:settings]&.to_unsafe_h),
      sound: SoundSettings.normalize(raw[:sound]&.to_unsafe_h, kind)
    )
  end
end
