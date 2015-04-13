defmodule TTT do

  @moduledoc """
  Board squares
  |1|2|3|
  |4|5|6|
  |7|8|9|
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

  defmodule EnforceTurns do

    @allXs (for s <- 1..9 do
      {:x, s}
    end)

    @allYs (for s <- 1..9 do
      {:y, s}
    end)

    def start do
      waitX
    end

    defp waitX do
      Bp.sync :bp, %Bp.Sync{wait: @allXs, block: @allYs}
      waitY
    end

    defp waitY do
      Bp.sync :bp, %Bp.Sync{wait: @allYs, block: @allXs}
      waitY
    end

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


