defmodule TTT do

  @moduledoc """
  Board squares
  |1|2|3|
  |4|5|6|
  |7|8|0|
  """

  defmodule DetectWin do

    def start(player, squares), do: loop(player, squares)

    defp loop(player, [square|rest]) do
      Bp.sync :bp, %Bp.Sync{wait: [{player, square}]}
      loop(player, rest)
    end
    defp loop(player, []), do: declare_win(player)

    defp declare_win(player) do
      Bp.sync :bp, %Bp.Sync{request: [{:win, player}]}
    end

  end


  def enforce_turns do
  end


  def disallow_square_reuse do
  end


  def default_moves do
  end


  def prevent_line_with_two do
  end


  def complete_line_with_two do
  end


  def intercept_single_fork do
  end


  def intercept_double_fork do
  end


end


