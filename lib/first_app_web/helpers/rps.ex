defmodule FirstAppWeb.RPS do
  @moduledoc """
  Simple Rock–Paper–Scissors winner determination.
  """

  @rules %{
    "Rock" => "Scissors",
    "Scissors" => "Paper",
    "Paper" => "Rock"
  }

  @spec determine_winner(map(), map()) :: String.t() | nil
  def determine_winner(%{login: left_login, selected: left_choice},
                       %{login: right_login, selected: right_choice}) do
    cond do
      left_choice == right_choice ->
        nil  # tie

      @rules[left_choice] == right_choice ->
        left_login  # left wins

      @rules[right_choice] == left_choice ->
        right_login  # right wins

      true ->
        nil  # invalid inputs or empty selections
    end
  end
end
