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

    @allOs (for s <- 1..9 do
      {:o, s}
    end)

    def start, do: waitX

    defp waitX do
      Bp.sync :bp, %Bp.Sync{wait: @allXs, block: @allOs}
      waitO
    end

    defp waitO do
      Bp.sync :bp, %Bp.Sync{wait: @allOs, block: @allXs}
      waitX
    end

  end


  defmodule DisallowSquareReuse do

    def start(square) do
      Bp.sync :bp, %Bp.Sync{wait: [{:x, square}, {:o, square}]}
      Bp.sync :bp, %Bp.Sync{block: [{:x, square}, {:o, square}]}
    end

  end


  defmodule DefaultMoves do

    @default_moves [
      {:o, 5},
      {:o, 1},
      {:o, 3},
      {:o, 7},
      {:o, 9},
      {:o, 2},
      {:o, 4},
      {:o, 6},
      {:o, 8}
    ]

    @all_moves (for s <- 1..9 do
      {:x, s}
    end) ++ (for s <- 1..9 do
      {:o, s}
    end) ++ [{:win, :x}, {:win, :o}]

    def start do
      Bp.sync :bp, %Bp.Sync{request: @default_moves, wait: @all_moves}
      start
    end

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


