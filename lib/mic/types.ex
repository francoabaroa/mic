defmodule Mic.Types do
  @moduledoc """
  Defines shared types used across the application.
  """

  # #############################################
  # available_subject_and_assistant_types start #
  # #############################################
  @type available_subject_and_assistant_types_ ::
          :distribution | :finance | :production | :contract_analyzer | :mental_wellness

  @available_subject_and_assistant_types_ [
    :distribution,
    :finance,
    :production,
    :contract_analyzer,
    :mental_wellness
  ]

  def available_subject_and_assistant_types do
    @available_subject_and_assistant_types_
  end

  # #############################################
  # available_subject_and_assistant_types end   #
  # #############################################
end
